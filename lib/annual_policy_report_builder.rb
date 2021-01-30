require 'spreadsheet'
require 'csv'

class AnnualPolicyReportBuilder


  attr_reader :calender_year 

  def initialize(calender_year)
    @calender_year = calender_year
  end

  def generate
    workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => "#{calender_year} QHP Policies"
    index = 0
    
    @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
    @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

    columns = ['POLICY ID', 'Subscriber Hbx ID', 'Recipient Address', 'NPT policy']
    7.times {|i| columns += ["NAME#{i+1}", "SSN#{i+1}", "DOB#{i+1}", "BEGINDATE#{i+1}", "ENDDATE#{i+1}"]}
    columns += ['ISSUER NAME']
    12.times {|i| columns += ["PREMIUM#{i+1}", "SLCSP#{i+1}", "APTC#{i+1}"]}
    sheet.row(index).concat columns

    # book = Spreadsheet.open "#{Rails.root}/2017_RP_UQHP_1095A_Data.xls"
    # @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
    #   if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[4].to_s.strip.blank?)
    #   else
    #     data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.strip.split("T")[0], "%Y-%m-%d")]
    #   end
    #   data
    # end

    current = 0

    policies_by_subscriber_1095a.each do |row, policies|
      policies.each do |policy|
        begin
          current += 1
          puts "at #{current}" if current % 100 == 0

          next if policy.kind == 'coverall'
          next unless valid_policy?(policy)

          input_builder = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: "new"})
          input_builder.carrier_hash = @carriers
          input_builder.settings = @settings
          input_builder.process
          input_builder

          if policy.responsible_party_id.present?
            if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
              puts "responsible party #{responsible_party.id} #{policy.id} address attached"          
              input_builder.append_recipient_address(responsible_party)
            else 
              raise "Responsible address missing!!"
            end
          end

          @notice = input_builder.notice

          if (@notice.recipient_address.to_s.match(/609 H St NE/i).present? || @notice.recipient_address.to_s.match(/1225 Eye St NW/i).present?)
            puts "#{@notice.recipient_address.to_s} #{@notice.policy_id}"
            next
          end

          @data = [ @notice.policy_id, policy.subscriber.person.authority_member.hbx_member_id, @notice.recipient_address.to_s,  policy.term_for_np]
          append_coverage_household

          @data += [@notice.issuer_name]
          append_premiums

          index += 1

          if (index % 100) == 0
            puts "found #{index} policies"
          end

          sheet.row(index).concat @data
        rescue Exception => e
          puts policy.id
          puts e.to_s.inspect
        end
      end
    end

    workbook.write "#{Rails.root.to_s}/IVL_#{calender_year}_QHP_1095A_Data_#{Time.now.strftime("%m_%d_%Y_%H_%M")}.xls"
  end

  def append_covered_member(indiv)
    @data += [indiv.name, indiv.ssn, indiv.dob, indiv.coverage_start_date, indiv.coverage_termination_date]
  end

  def append_coverage_household
    @notice.covered_household.each do |indiv|
      append_covered_member(indiv)
    end
    (7 - @notice.covered_household.size).times{ append_blank_arr(5) }
  end

  def append_blank_arr(size)
    size.times{ @data << '' }
  end

  def append_premiums
    (1..12).each do |index|
      monthly_premium = @notice.monthly_premiums.detect{|p| p.serial == index}
      if monthly_premium.blank?
        append_blank_arr(3)
      else
        @data += [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc]
      end
    end
  end

  def rejected_policy?(policy)
    edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
    return true if edi_transactions.size == 1 && edi_transactions.first.aasm_state == 'rejected'
    false
  end

  def valid_policy?(policy)
    return false if policy.canceled?
    return false unless policy.plan.coverage_type =~ /health/i
    return false if policy.plan.metal_level =~ /catastrophic/i
    active_enrollees = policy.enrollees.reject{|en| en.canceled?}
    return false if active_enrollees.empty? || rejected_policy?(policy) || !policy.belong_to_authority_member?
    return false if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
    true
  end

  def policies_by_subscriber_1095a
    plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i}).map(&:id)

    p_repo = {}
    Person.no_timeout.each do |person|
      person.members.each do |member|
        p_repo[member.hbx_member_id] = person._id
      end
    end

    pols = PolicyStatus::Active.between(Date.new(calender_year-1,12,31), Date.new(calender_year,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }).group_by { |p| p_repo[p.subscriber.m_id] }
  end

  # def prepend_zeros(number, n)
  #   (n - number.to_s.size).times { number.prepend('0') }
  #   number
  # end
end
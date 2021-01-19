require 'spreadsheet'
require 'csv'

class ExcelReportBuilder

  def has_aptc_during_year?(policy)
    # policy.applied_aptc.to_f > 0

    # aptcs = policy.versions.map(&:applied_aptc).map{ |x| x.to_f } + [ policy.applied_aptc.to_f ]
    # aptcs.uniq.any? {|aptc| aptc > 0}

    policy.aptc_credits.any? || policy.applied_aptc.to_f > 0
  end

  def aptc_report
    workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => '2014 QHP Policies'
    index = 1
    @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}

    columns = ['Enrollment Group ID', 'PolicyId', 'HbxId', 'Full name','Carrier', 'Hios Plan ID', 'Plan Year', 'Plan Name', 'Coverage Start', 'Coverage End']
    12.times {|i| columns += ["#{i+1}/2016 Premium", "#{i+1}/2016 APTC"]}

    sheet.row(0).concat columns
    count = 0

    policies_by_subscriber.each do |id, policies|
      count += 1

      if (count % 100) == 0
        puts "looked at #{count} records..."
      end

      if policies.size > 10
        puts "found......#{policies.count}....#{policies.first.id}"
      end

      policies.each do |policy|
        begin
          # if has_aptc_during_year?(policy)
            next if !policy.terminated?
            next if policy.canceled?

            active_enrollees = policy.enrollees.reject{|en| en.canceled?}

            next if active_enrollees.empty?
            next if rejected_policy?(policy)
            next if !policy.belong_to_authority_member?
            next if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)

            irs_input = Generators::Reports::IrsInputBuilder.new(policy)

            irs_input.carrier_hash = @carriers
            irs_input.process

            sheet.row(index).concat build_aptc_row(policy, irs_input.notice)

            index += 1

            if (index % 50) == 0
              puts "found....#{index}"
            end
          # end
        rescue Exception => e
          puts e.to_s
        end
      end
    end

    workbook.write "#{Rails.root.to_s}/terminated_policies_2014.xls"
  end

  def build_aptc_row(policy, notice)
    data = [
      policy.eg_id,
      policy.id,
      policy.subscriber.hbx_member_id,
      policy.subscriber.person.full_name,
      @carriers[policy.plan.carrier_id],
      policy.plan.hios_plan_id,
      policy.plan.year,
      policy.plan.name,
      notice.recipient.coverage_start_date,
      notice.recipient.coverage_termination_date
    ]

    data + (1..12).inject([]) do |data, index|
      monthly_premium = notice.monthly_premiums.detect{|p| p.serial == index}
      data << (monthly_premium.blank? ? nil : monthly_premium.premium_amount)
      data << (monthly_premium.blank? ? nil :  monthly_premium.monthly_aptc)
    end
  end


  def get_aptc_maintainance_details
    workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => 'Multi Assisted QHP'
    index = 1
    count = 0

    columns = ['Integrated Case', 'Primary', 'Address Line 1', 'Apt/Ste', 'Address Line 2', 'City', 'State', 'Zip', 'APTC', 'Last Update']
 
    sheet.row(0).concat columns

    CSV.foreach("#{Rails.root}/December Terms - full list.csv") do |row|

      next if row[0].strip == 'Integrated Case'

      e_case_id = row[0].strip
      full_name = row[1].strip

      puts full_name.inspect

      # people = Person.where(name_full: full_name)

      app_group = ApplicationGroup.where(e_case_id: e_case_id)

      # if people.count > 1
      #   count += 1
      #   # puts "----- zero or more than 1"
      # end

      if app_group.count == 1
        count += 1
        # puts "----- zero or more than 1"
      end

      sheet.row(index).concat row.split(',')
      index += 1
    end  
    puts count                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             
    # workbook.write "#{Rails.root.to_s}/#{file}"
  end

  def build_1095a_report
    workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => 'UnAssisted QHP'
    index = 0
    failed = 0
    @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}
    @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

    columns = ['POLICY ID', 'Subscriber Hbx ID', 'Recipient Address']
    7.times {|i| columns += ["NAME#{i+1}", "SSN#{i+1}", "DOB#{i+1}", "BEGINDATE#{i+1}", "ENDDATE#{i+1}"]}
    columns += ['ISSUER NAME']
    12.times {|i| columns += ["PREMIUM#{i+1}", "SLCSP#{i+1}", "APTC#{i+1}"]}
    sheet.row(index).concat columns


      book = Spreadsheet.open "#{Rails.root}/2017_RP_UQHP_1095A_Data.xls"
      @responsible_party_data = book.worksheets.first.inject({}) do |data, row|
        if row[2].to_s.strip.match(/Responsible Party SSN/i) || (row[2].to_s.strip.blank? && row[4].to_s.strip.blank?)
        else
          data[row[0].to_s.strip.to_i] = [prepend_zeros(row[2].to_i.to_s, 9), Date.strptime(row[3].to_s.strip.split("T")[0], "%Y-%m-%d")]
        end
        data
      end


      @npt_policies = []
      CSV.foreach("#{Rails.root}/2017_NPT_UQHP_20180126.csv", headers: :true) do |row|
        @npt_policies << row[0].strip
      end


    # skip_list = []

    # book = Spreadsheet.open "#{Rails.root}/INCLUSION_CF_AETNA_DUPE_OVERLAP_UPDATES_20160201-0800.xls"
    # inclusion_list = book.worksheets.first.inject([]){|data, row| data << row[0].to_s.strip.to_i}.compact

    # puts inclusion_list.inspect

    # kaiser_plans = Plan.where(carrier_id: "53e67210eb899a460300000d", year: 2015).map(&:id)

    kaiser_plans = []
    current = 0

    responsible_party = 0
    missing_enrollees = []
    non_authority = []
    multi_aptc = []
    
    counter = 0
    policies_by_subscriber_1095a.each do |row, policies|
    # inclusion_list.each do |policy_id|
      # policies = [Policy.find(policy_id)].compact

      policies.each do |policy|
        begin
          current += 1

          if current % 1000 == 0
            puts "at #{current}"
          end

          # next unless policy.multi_aptc?

          # if policy.responsible_party_id.present?
          #   responsible_party << policy.id
          #   next
          # end
          # next unless inclusion_list.include?(policy.id)

          # next if skip_list.include?(policy.id)

          # next if [92293, 106028, 116523, 123827].include?(policy.id)

          counter += 1

          # if policy.responsible_party_id.present?
          #   puts "found responsible party -- #{policy.id}"
          #   responsible_party += 1
          #   next
          # end

          if !valid_policy?(policy)
            # puts "invalid policy #{policy.id}"
            next
          end

          next if policy.kind == 'coverall'

          if policy.multi_aptc?
            multi_aptc << policy.id
          end

          next if (policy.applied_aptc > 0 || policy.multi_aptc?)

          # if skip_list.include?(policy.id)
          #   puts "skipped....#{policy.id}"
          #   next
          # end

          # if policy.responsible_party_id.present?
          #   puts "responsible party...#{policy.id}"
          #   next
          # end 

          # next unless kaiser_plans.include?(policy.plan_id)
          # next unless (policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end.end_of_month != policy.subscriber.coverage_end))

          input_builder = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: "new", npt_policy: @npt_policies.include?(policy.id.to_s) })
          input_builder.carrier_hash = @carriers
          input_builder.settings = @settings
          input_builder.process
          input_builder

          if policy.responsible_party_id.present?
            if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(policy.responsible_party_id)).first
              puts "responsible party #{responsible_party.id} #{policy.id} address attached"          
              input_builder.append_recipient_address(responsible_party)
              # input_builder.append_recipient(responsible_party)
            else 
              raise "Responsible address missing!!"
            end
          end

          @notice = input_builder.notice

          responsible_party_date = @responsible_party_data[@notice.policy_id.to_i]

          # @notice.recipient_address = nil if policy.responsible_party_id.present?

          if (@notice.recipient_address.to_s.match(/609 H St NE/i).present? || @notice.recipient_address.to_s.match(/1225 Eye St NW/i).present?)
            puts @notice.recipient_address.to_s
            next
          end

          @data = [ @notice.policy_id, policy.subscriber.person.authority_member.hbx_member_id, @notice.recipient_address.to_s ]

          append_coverage_household
          @data += [@notice.issuer_name]
          append_premiums


          index += 1

          if (index % 100) == 0
            puts "found #{index}"
          end

          sheet.row(index).concat @data
        rescue Exception => e
          puts policy.id
          puts e.to_s.inspect
          failed += 1
        end
      end
    end

    puts "failed-----#{failed}---#{counter}"
    puts missing_enrollees.inspect
    puts responsible_party.inspect
    puts multi_aptc.inspect
    # puts non_authority.inspect

    workbook.write "#{Rails.root.to_s}/IVL_UQHP_1095A_#{Time.now.strftime("%m_%d_%Y_%H_%M")}.xls"
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

    #p_map = Person.collection.aggregate([{"$unwind"=> "$members"}, {"$project" => {"_id" => 0, member_id: "$members.hbx_member_id", person_id: "$_id"}}])

    Person.each do |person|
      person.members.each do |member|
        # p_map.each do |val|

          p_repo[member.hbx_member_id] = person._id
        # end
      end
    end

    pols = PolicyStatus::Active.between(Date.new(2016,12,31), Date.new(2017,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }).group_by { |p| p_repo[p.subscriber.m_id] }
  end

  def prepend_zeros(number, n)
    (n - number.to_s.size).times { number.prepend('0') }
    number
  end

  def policies_by_subscriber
    carrier = Carrier.where(:name => "CareFirst").first
    plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i, :carrier_id => carrier.id}).map(&:id)

    p_repo = {}

    p_map = Person.collection.aggregate([{"$unwind"=> "$members"}, {"$project" => {"_id" => 0, member_id: "$members.hbx_member_id", person_id: "$_id"}}])

    p_map.each do |val|
      p_repo[val["member_id"]] = val["person_id"]
    end

    pols = PolicyStatus::Active.between(Date.new(2015,12,31), Date.new(2016,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }).group_by { |p| p_repo[p.subscriber.m_id] }
  end
end
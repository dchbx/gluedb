require 'spreadsheet'
require 'csv'

class AuditReportBuilder

  CALENDER_YEAR = 2017

  def qhp_audit_report
    workbook = Spreadsheet::Workbook.new
    sheet = workbook.create_worksheet :name => "#{CALENDER_YEAR} QHP Policies"
    index = 1
    @carriers = Carrier.all.inject({}){|hash, carrier| hash[carrier.id] = carrier.name; hash}

    columns = %W(POLICYID STATUS LASTNAME FIRSTNAME MI MEMBERID DOB GENDER DEPENDENTS PLANNAME PLANID METALLEVEL STARTDATE ENDDATE)
    
    # columns = ['ENROLLMENT GROUP ID']
    # columns += %W(POLICYID MEMBERID LASTNAME FIRSTNAME MI PLANID PLANNAME STARTDATE ENDDATE)

    12.times {|i| columns += ["PREMIUM#{i+1}", "APTC#{i+1}"]}

    @npt_policies = []
    CSV.foreach("#{Rails.root}/2018_NPT_data.csv", headers: :true) do |row|
      @npt_policies << row[0].strip
    end

    # CSV.foreach("#{Rails.root}/2016_1095_NPT_20170206.csv", headers: :true) do |row|
    #   @npt_policies << row[0].strip
    # end

    # @npt_policies = []
    # CSV.foreach("#{Rails.root}/2017_NPT_UQHP_20180126.csv", headers: :true) do |row|
    #   @npt_policies << row[0].strip
    # end

    # CSV.foreach("#{Rails.root}/2017_NPT_AQHP_20180129.csv", headers: :true) do |row|
    #   @npt_policies << row[0].strip
    # end

    @settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access

    sheet.row(0).concat columns
    count = 0
    # process = false

    policies_by_subscriber.each do |id, policies|
      policies.each do |policy|

        count += 1

        if count % 200 == 0
          puts "processed #{count}"
        end

        # next if policy.id.to_i == 119089
        # if policy.id.to_i == 113553
        #   process = true
        # end

        # next unless process
        # next if index > 100

        begin
          # next if policy.canceled?
          # next if policy.subscriber.coverage_end.present? && policy.subscriber.coverage_end < Date.new(2015,10,1)

          # next if policy.subscriber.coverage_start >= Date.new(2016,10,1)

          # next unless policy.terminated?

          # next if !policy.canceled? && policy.subscriber.coverage_end.present? && policy.subscriber.coverage_end < Date.new(2014, 10, 1)
          # next if policy.canceled?
          # next if policy.subscriber.coverage_start >= Date.new(2016, 1, 1) && policy.subscriber.coverage_start < Date.new(2016, 10, 1)
          # next unless policy.belong_to_authority_member?

          next unless valid_policy?(policy)
          # next if !valid_canceled_policy?(policy)
          # next unless (policy.applied_aptc > 0 || policy.multi_aptc?)

          npt_policy = false

          if @npt_policies.include?(policy.id.to_s)
            npt_policy = true
            puts "Found npt policy #{policy.id}"
          end

          irs_input = Generators::Reports::IrsInputBuilder.new(policy, { notice_type: "new", npt_policy: npt_policy })
          irs_input.carrier_hash = @carriers
          irs_input.settings = @settings
          irs_input.process

          sheet.row(index).concat build_business_audit_row(policy, irs_input.notice)

          index += 1
        rescue Exception => e
          puts e.to_s
        end
      end
    end

    workbook.write "#{Rails.root.to_s}/audit_report_#{CALENDER_YEAR}.xls"
  end

  private

  def policies_by_subscriber
    # carrier = Carrier.where(:name => "Kaiser").first
    # plans = Plan.where({:year => 2017, :carrier_id => carrier.id}).map(&:id)
    # # plans = Plan.where({:year => 2016}).map(&:id)

    # p_repo = {}
    # p_map = Person.collection.aggregate([{"$unwind"=> "$members"}, {"$project" => {"_id" => 0, member_id: "$members.hbx_member_id", person_id: "$_id"}}])
    # p_map.each do |val|
    #   p_repo[val["member_id"]] = val["person_id"]
    # end

    # plans = Plan.where({:metal_level => {"$not" => /catastrophic/i}, :coverage_type => /health/i, :year => 2017}).map(&:id)
    plans = Plan.where({:year => CALENDER_YEAR}).map(&:id)

    p_repo = {}
    Person.each do |person|
      person.members.each do |member|
        p_repo[member.hbx_member_id] = person._id
      end
    end

    pols = PolicyStatus::Active.between(Date.new(CALENDER_YEAR,9,30), Date.new(CALENDER_YEAR,12,31)).results.where({
      :plan_id => {"$in" => plans}, :employer_id => nil
      }) #.group_by { |p| p_repo[p.subscriber.m_id] }

    # pols = PolicyStatus::Active.between(Date.new(CALENDER_YEAR - 1,12,31), Date.new(CALENDER_YEAR,9,30)).results.where({
    #   :plan_id => {"$in" => plans}, :employer_id => nil
    #   })

    puts "Found....#{pols.size}"

    pols.group_by { |p| p_repo[p.subscriber.m_id] }
  end
 
  def build_business_audit_row(policy, notice)
    person = policy.subscriber.person
    data = [
      # policy.eg_id,
      policy.id,
      # policy.subscriber.hbx_member_id,
      policy.aasm_state.humanize,
      person.name_last,
      person.name_first,
      person.name_middle,
      person.authority_member.hbx_member_id,
      person.authority_member.dob.strftime("%m/%d/%Y"),
      person.authority_member.gender,
      policy.canceled? ? policy.enrollees_sans_subscriber.size : policy.enrollees_sans_subscriber.reject{|member| member.canceled? }.size,
      policy.plan.name,
      policy.plan.hios_plan_id,
      policy.plan.metal_level,
      notice.recipient.coverage_start_date,
      notice.recipient.coverage_termination_date
    ]

    data = data + (1..12).inject([]) do |data, index|
      monthly_premium = notice.monthly_premiums.detect{|p| p.serial == index}
      data << ((monthly_premium.blank? || index < 10) ? nil : monthly_premium.premium_amount)
      data << ((monthly_premium.blank? || index < 10) ? nil : monthly_premium.monthly_aptc)

      # data << (monthly_premium.blank? ? nil : monthly_premium.premium_amount)
      # data << (monthly_premium.blank? ? nil : monthly_premium.monthly_aptc)

      # data << ((monthly_premium.blank?) ? nil : monthly_premium.premium_amount)
      # data << ((monthly_premium.blank?) ? nil : monthly_premium.monthly_aptc)

      # data += (monthly_premium.blank? ? [nil, nil] : [monthly_premium.premium_amount, monthly_premium.monthly_aptc])
    end

    # puts "----here"
    # if (policy.id.to_s == "95315" || policy.id.to_s == "122152")
    #   puts notice.monthly_premiums.inspect
    #   puts data.inspect
    # end

    data
  end

  def rejected_policy?(policy)
    edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => policy.id })
    return true if edi_transactions.size == 1 && edi_transactions.first.aasm_state == 'rejected'
    false
  end

  def valid_policy?(policy)
    # return false if policy.canceled?
    # return false unless policy.plan.coverage_type =~ /health/i
    # return false if policy.plan.metal_level =~ /catastrophic/i
    # active_enrollees = policy.enrollees.reject{|en| en.canceled?}
    # return false if active_enrollees.empty? || 
    return false if rejected_policy?(policy) || !policy.belong_to_authority_member?
    # return false if policy.subscriber.coverage_end.present? && (policy.subscriber.coverage_end < policy.subscriber.coverage_start)
    true
  end

  def valid_canceled_policy?(policy)
    return false if rejected_policy?(policy) || !policy.belong_to_authority_member?
    true
  end
end


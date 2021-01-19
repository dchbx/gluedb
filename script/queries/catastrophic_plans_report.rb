# rails runner script/queries/catastrophic_plans_report.rb <year> -e production
require 'csv'

header_row = ["Glue_Policy_ID", "Enrollment_Group_ID", "Subscriber_First_Name", "Subscriber_Last_Name", "Subscriber_HBX_ID", "Authority_Member_Policy?", "Metal_Level", "Carrier", "HIOS_ID", "State", "Coverage_Start", "Coverage_End", "Premium_Amount_Total", "APTC"]
year = ARGV[0]

if year.blank?
  puts "Please include mandatory argument: Year. Example: rails runner script/queries/catastrophic_plans_report.rb <year>" unless Rails.env.test?
  return
end

year = year.to_i
CSV.open("catastrophic_plans_report_for_#{year}.csv",'w') do |csv|
  csv << header_row
  start_date = Date.new(year, 01, 01).beginning_of_day
  end_date = Date.new(year, 12, 31).end_of_day
  catastrophic_plan_ids = Plan.where(metal_level: 'catastrophic', year: year).pluck(:id)
  policies = Policy.where(:"plan_id".in => catastrophic_plan_ids, :"enrollees.coverage_start" => { "$gte" => start_date, "$lte" => end_date} )
  policies.each do |policy|
    next if policy.subscriber.coverage_start.year != year
    next policy if policy.aasm_state == 'canceled'
    begin
      csv << [
        policy.id,
        policy.eg_id,
        policy.subscriber.person.name_first,
        policy.subscriber.person.name_last,
        policy.subscriber.m_id,
        policy.belong_to_authority_member?,
        policy.plan.metal_level,
        policy.carrier.name,
        policy.plan.hios_plan_id,
        policy.aasm_state,
        policy.subscriber.coverage_start,
        policy.subscriber.coverage_end,
        policy.pre_amt_tot,
        policy.applied_aptc
      ]
    rescue => e
      puts e.backtrace unless Rails.env.test?
    end
  end
end

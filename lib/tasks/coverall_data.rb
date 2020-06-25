# Please run this script  RAILS_ENV=production rails runner lib/tasks/coverall_data.rb "10/1/2018" "09/30/2019"

require 'csv'

if ARGV[0].blank? || ARGV[1].blank?
  raise "Please pass arguments" unless Rails.env.test?
end

start_date = Date.strptime(ARGV[0], "%m/%d/%Y")
end_date = Date.strptime(ARGV[1], "%m/%d/%Y")

CSV.open("#{Rails.root}/#{start_date.year}_to_#{end_date.year}_coverall_data.csv", "w", force_quotes: true) do |csv|
  csv << %w(POLICY_ID EG_ID STATUS FIRST_NAME MIDDLE_NAME LAST_NAME ENROLLEE_M_ID MEMBER_ID DOB GENDER  IS_SUBSCRIBER? DEPENDENTS_COUNT PLAN_ID HIOS_PLAN_ID PLAN_NAME METAL_LEVEL COVERAGE_TYPE COVERAGE_START COVERAGE_END)
  policies = Policy.where("kind" => "coverall", :enrollees => {"$elemMatch" => { "rel_code" => "self", :coverage_start => {"$gte"=>start_date, "$lte"=>end_date}}})
  policies.no_timeout.each do |pol|
    begin
      plan = pol.plan
      dep_count = pol.enrollees.where(:rel_code.ne => "self").count
      ens = pol.enrollees
      ens.each do |en|
        if en.rel_code == "self"
          coverage_start = en.try(:coverage_start).to_s
          coverage_end = en.try(:coverage_end).to_s
          m_id = en.try(:m_id)
          person = en.try(:person)
          first_name = person.try(:name_first)
          last_name = person.try(:name_last)
          middle_name = person.try(:name_middle)
          hbx_id = person.try(:authority_member_id)
          if en.try(:rel_code) == "self"
            is_subscriber = true
          else
            is_subscriber = false
          end
          if person.present? && person.members.present?
            member = person.members.where(hbx_member_id: hbx_id).first
            dob = member.try(:dob).to_s
            gender = member.gender
          else
            member = nil
            dob = nil
            gender = nil
          end
          csv << [pol.id, pol.eg_id, pol.aasm_state, first_name, middle_name, last_name, m_id, hbx_id, dob, gender, is_subscriber, dep_count, plan.id, plan.hios_plan_id, plan.name, plan.metal_level, pol.coverage_type, coverage_start, coverage_end]
        end
      end
    rescue => e
      puts "Policy #{pol.eg_id}"
      puts e.message
    end
  end
  puts "Process Completed"
end
# Please run this script RAILS_ENV=production rails runner lib/tasks/person_records_1095A.rb "1/1/2019" "12/31/2019"

require 'csv' 
if ARGV[0].blank? || ARGV[1].blank?
  raise "Please pass arguments" unless Rails.env.test?
end

start_date = Date.strptime(ARGV[0], "%m/%d/%Y")
end_date = Date.strptime(ARGV[1], "%m/%d/%Y")

CSV.open("#{Rails.root}/#{start_date.year}_to_#{end_date.year}_person_records_1095A.csv", "w", force_quotes: true) do |csv|
  csv << %w(Policy_eg_id enrollee_count relationship enrollee_m_id Primary_subscriber_HBX_ID first_name last_name full_name dob ssn)
  policies = Policy.where("employer_id" => nil, "aasm_state" => {"$ne" => "canceled"}, :enrollees => {"$elemMatch" => { "rel_code" => "self", :coverage_start => {"$gte"=>start_date, "$lte"=>end_date}}})
  policies.no_timeout.each do |pol|
    next unless pol.plan.coverage_type == "health"
    ens = pol.enrollees
    ens.each do |en|
      if en.rel_code == "self"
        m_id = en.try(:m_id)
        person = en.try(:person)
        first_name = person.try(:name_first)
        last_name = person.try(:name_last)
        full_name = person.try(:name_full)
        hbx_id = person.try(:authority_member_id)
        rel_code = en.try(:rel_code)
        if person.present? && person.members.present?
          member = person.members.where(hbx_member_id: hbx_id).first
          ssn = member.try(:ssn)
          dob = member.try(:dob).to_s
        else
          member = nil
          ssn = nil
          dob = nil
        end
        csv << [pol.eg_id, ens.count, rel_code, m_id, hbx_id, first_name, last_name, full_name, dob, ssn]
      end
    end
  end
end

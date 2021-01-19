require 'csv'
timey = Time.now
puts "Report started at #{timey}"
policies = Policy.no_timeout.where(
  {"eg_id" => {"$not" => /DC0.{32}/},
   :enrollees => {"$elemMatch" =>
      {:rel_code => "self",
            :coverage_start => {"$gt" => Date.new(2017,12,31)}}}}
)

policies = policies.reject{|pol| pol.market == 'individual' && 
                                 !pol.subscriber.nil? &&
                                 (pol.subscriber.coverage_start.year == 2014||
                                  pol.subscriber.coverage_start.year == 2015||
                                  pol.subscriber.coverage_start.year == 2016) }


def bad_eg_id(eg_id)
  (eg_id =~ /\A000/) || (eg_id =~ /\+/)
end

count = 0
total_count = policies.size

timestamp = Time.now.strftime('%Y%m%d%H%M')

Caches::MongoidCache.with_cache_for(Carrier, Plan, Employer) do

  CSV.open("stephen_expected_effectuated_20140930_#{timestamp}.csv", 'w') do |csv|
    csv << ["Subscriber ID", "Member ID" , "Policy ID", "Enrollment Group ID", "Status",
            "First Name", "Last Name","SSN", "DOB", "Gender", "Relationship",
            "Plan Name", "HIOS ID", "Plan Metal Level", "Carrier Name",
            "Premium Amount", "Premium Total", "Policy APTC", "Policy Employer Contribution",
            "Coverage Start", "Coverage End",
            "Employer Name", "Employer DBA", "Employer FEIN", "Employer HBX ID",
            "Home Address", "Mailing Address","Email","Phone Number","Broker"]
    policies.each do |pol|
      count += 1
      puts "#{count}/#{total_count} done at #{Time.now}" if count % 10000 == 0
      puts "#{count}/#{total_count} done at #{Time.now}" if count == total_count
      if !bad_eg_id(pol.eg_id)
        if !pol.subscriber.nil?
          #if !pol.subscriber.canceled?
            subscriber_id = pol.subscriber.m_id
            next if pol.subscriber.person.blank?
            subscriber_member = pol.subscriber.member
            auth_subscriber_id = subscriber_member.person.authority_member_id

            if !auth_subscriber_id.blank?
              if subscriber_id != auth_subscriber_id
                next
              end
            end
            plan = Caches::MongoidCache.lookup(Plan, pol.plan_id) {
              pol.plan
            }
            carrier = Caches::MongoidCache.lookup(Carrier, pol.carrier_id) {
              pol.carrier
            }
            employer = nil
            if !pol.employer_id.blank?
            employer = Caches::MongoidCache.lookup(Employer, pol.employer_id) {
              pol.employer
            }
            end
            if !pol.broker.blank?
              broker = pol.broker.full_name
            end
            pol.enrollees.each do |en|
              #if !en.canceled?
                per = en.person
                next if per.blank?
                csv << [
                  subscriber_id, en.m_id, pol._id, pol.eg_id, pol.aasm_state,
                  per.name_first,
                  per.name_last,
                  en.member.ssn,
                  en.member.dob.strftime("%Y%m%d"),
                  en.member.gender,
                  en.rel_code,
                  plan.name, plan.hios_plan_id, plan.metal_level, carrier.name,
                  en.pre_amt, pol.pre_amt_tot,pol.applied_aptc, pol.tot_emp_res_amt,
                  en.coverage_start.blank? ? nil : en.coverage_start.strftime("%Y%m%d"),
                  en.coverage_end.blank? ? nil : en.coverage_end.strftime("%Y%m%d"),
                  pol.employer_id.blank? ? nil : employer.name,
                  pol.employer_id.blank? ? nil : employer.dba,
                  pol.employer_id.blank? ? nil : employer.fein,
                  pol.employer_id.blank? ? nil : employer.hbx_id,
                  per.home_address.try(:full_address) || pol.subscriber.person.home_address.try(:full_address),
                  per.mailing_address.try(:full_address) || pol.subscriber.person.mailing_address.try(:full_address),
                  per.emails.first.try(:email_address), per.phones.first.try(:phone_number), broker
                ]
              #end
            end
          #end
        end
      end
    end
  end

end

timey2 = Time.now
puts "Report ended at #{timey2}"

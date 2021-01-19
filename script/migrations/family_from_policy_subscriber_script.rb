#Usage
#rails r script/migrations/family_from_policy_subscriber_script.rb BEGIN-DATE END-DATE
#BEGIN-DATE, END-DATE  format = MMDDYYYY
#E.g. rails r script/migrations/family_from_policy_subscriber_script.rb 01012017 01122017

require File.join(Rails.root, "script", "migrations", "family_from_policy_subscriber")
require File.join(Rails.root, "app", "models", "queries", "policies_with_no_families")

log_path = "#{Rails.root}/log/family_from_policy_subscriber_script.log"
@logger = Logger.new(log_path)

puts "Logs written to #{log_path}"

begin
  @begin_date = Date.strptime(ARGV[0], "%m%d%Y")
  @end_date = Date.strptime(ARGV[1], "%m%d%Y")
  puts "begin_date #{@begin_date} end_date #{@end_date}"
rescue Exception => e
  puts "Error #{e.message}"
  puts "Usage:"
  puts "rails r script/migrations/family_from_policy_subscriber_script.rb BEGIN-DATE END-DATE"
  puts "rails r script/migrations/family_from_policy_subscriber_script.rb 01012017 01122017"
  exit
end

@logger.info "#{Time.now} script/migrations/family_from_policy_subscriber_script.rb"
@logger.info "Begin_date #{@begin_date} end_date #{@end_date}"


def add_hbx_enrollment(family, policy)

  return if family.active_household.nil?

  hbx_enrollement = family.active_household.hbx_enrollments.build
  hbx_enrollement.policy = policy
  hbx_enrollement.elected_aptc_in_dollars = policy.elected_aptc
  hbx_enrollement.applied_aptc_in_dollars = policy.applied_aptc
  hbx_enrollement.submitted_at = family.submitted_at

  hbx_enrollement.kind = "employer_sponsored" unless policy.employer_id.blank?
  hbx_enrollement.kind = "unassisted_qhp" if (hbx_enrollement.applied_aptc_in_cents == 0 && policy.employer.blank?)
  hbx_enrollement.kind = "insurance_assisted_qhp" if (hbx_enrollement.applied_aptc_in_cents > 0 && policy.employer.blank?)

  policy.enrollees.each do |enrollee|
    begin
      person = Person.find_for_member_id(enrollee.m_id)
      family.family_members.build({person: person}) unless family.person_is_family_member?(person)
      family_member = family.find_family_member_by_person(person)
      hbx_enrollement_member = hbx_enrollement.hbx_enrollment_members.build({family_member: family_member,
                                                                             premium_amount_in_cents: enrollee.pre_amt})
      hbx_enrollement_member.is_subscriber = true if (enrollee.rel_code == "self")

    rescue FloatDomainError
      next
    end
  end
end

@logger.info "Starting to attach non primary-applicant's policies to families"
@logger.info "Total Families at start: #{Family.count}"
@logger.info "Total policies count: #{Policy.count}"
@logger.info "Persons count: #{Person.count}"

all_policies_with_no_families = Queries::PoliciesWithNoFamilies.new.execute
@logger.info "Total policies_with_no_families: #{all_policies_with_no_families.length}"

policy_groups = all_policies_with_no_families.where(:enrollees => {
  "$elemMatch" => { :rel_code => "self", :coverage_start.gte => @begin_date, :coverage_start.lte => @end_date }
  }).group_by do |policy|
  policy.subscriber.person.id
end

@logger.info "In given daterange: subscribers with policies not mapped to a family: #{policy_groups.length}"
@logger.info "policy_groups: #{policy_groups.length}"

policy_groups.each do |person_id, policies|  
  begin
    start = Time.now
    person = Person.find(person_id)
    families = Family.where({:family_members => {"$elemMatch" => {:person_id => Moped::BSON::ObjectId(person_id)}}})
    next if families.empty?

    if families.length > 1
      policy_groups.delete(person_id)
      @logger.info "Person belongs to multiple families. Person.authority_member_id #{person.authority_member_id} Family e_case_ids: #{families.map(&:e_case_id)}"
      next
    end
    
    family = families.first
    policies.each do |policy|
      add_hbx_enrollment(family, policy)
      family.save!
    end

    policy_groups.delete(person_id) #delete the subscriber as we have processed him/her

    finish = Time.now
    diff = finish - start
    @logger.info "Time took for #{person_id}....#{diff}"
  rescue Exception => e
    @logger.info "ERROR: #{e.message}"
  end
end

@logger.info "family_count after attaching non primary applicant policies: #{Family.count}"
@logger.info "Starting to create families for policies without families"
@logger.info "policy_groups remaing to create families: #{policy_groups.length}"

policy_groups.each do |person_id, policies|
  begin
    person = Person.find(person_id)
    family_from_policy_subscriber = FamilyFromPolicySubscriber.new(person, policies)
    family_from_policy_subscriber.create
    family_from_policy_subscriber.save
  rescue Exception => e
    @logger.info "ERROR: #{e.message} " + e.backtrace.join(' ')
  end
end

@logger.info "Total Families at end: #{Family.count}"
@logger.info "Total policies count: #{Policy.count}"
@logger.info "Persons count: #{Person.count}"
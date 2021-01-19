batch_size = 500
offset = 0
policy_count = Policy.count

csv =CSV.open("10655_export_glue_multi_row_sep_16_cancelled.csv", "w")

csv << %w(family.eg_id policy.eg_id hbx_enrollment.policy.policy_start policy.aasm_state policy.plan.coverage_type policy.plan.metal_level
        person.authority_member_id person.authority_member.is_incarcerated person.authority_member.citizen_status
        person.authority_member.is_state_resident is_dependent is_responsible_party?)

def add_to_csv(csv, policy, person, is_dependent=false, is_responsible_party=false)
  csv << ["FAMILY_ID", policy.eg_id, policy.policy_start, policy.aasm_state, policy.plan.coverage_type, policy.plan.metal_level, person.authority_member_id,
          person.authority_member.try(:is_incarcerated), person.authority_member.try(:citizen_status),
          person.authority_member.try(:is_state_resident)] + [is_dependent, is_responsible_party]
end

while offset < policy_count
    # Family.offset(offset).limit(batch_size).flat_map(&:households).flat_map(&:hbx_enrollments).each do |hbx_enrollment|
    Policy.offset(offset).limit(batch_size).each do |policy|
    begin
      next if policy.nil?
      next if policy.policy_start < Date.new( Date.today.year, 01, 01)
      # next if !policy.is_active?
      next if (policy.plan.metal_level == "catastrophic") ||
          (policy.applied_aptc != 0) || (policy.plan.market_type == 'shop')

      person = policy.subscriber.person

      add_to_csv(csv, policy, person, false, false)

      if policy.responsible_party.present?
        add_to_csv(csv, policy, policy.responsible_party.person, false, true)
      end

      policy.enrollees.each do |enrollee|
        add_to_csv(csv, policy, enrollee.person, true, false) if enrollee.person != person
      end
    rescue => e
      puts "Error policy eg_id #{policy.eg_id}" + e.message + " " + e.backtrace.first
    end
  end

  offset = offset + batch_size
end

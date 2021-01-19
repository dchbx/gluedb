namespace :developer do
  desc "Load Demo Policies"
  task :load_policies => "developer:load_plans" do
    plan = Plan.first
    policy = Policy.create!(
      eg_id: "123456", 
      preceding_enrollment_group_id: nil,
      allocated_aptc: "0.0",
      elected_aptc: "0.0",
      applied_aptc: "0.0",
      csr_amt: nil,
      pre_amt_tot: "0.0",
      tot_res_amt: "0.0",
      tot_emp_res_amt: "0.0",
      sep_reason: "open_enrollment",
      carrier_to_bill: false,
      aasm_state: nil,
      updated_by: nil,
      is_active: true,
      hbx_enrollment_ids: nil,
      carrier_specific_plan_id: nil,
      rating_area: nil,
      composite_rating_tier: nil,
      cobra_eligibility_date: nil,
      kind: "employer_sponsored",
      enrollment_kind: nil,
      term_for_np: false,
      hbx_enrollment_policy_id: nil,
      carrier_id: Carrier.where(hbx_carrier_id: "20014").first.id,
      broker_id: nil,
      plan_id: plan.id,
      employer_id: nil, 
      responsible_party_id: nil
    )
    relationships = {
      "self" => Person.where(name_first: "Tony").first,
      "spouse" => Person.where(name_first: "Pepper").first
    }
    relationships.each do |relationship, person|
      policy = Policy.last
      enrollee = policy.enrollees.build
      enrollee.relationship_status_code = relationship
      enrollee.m_id = person.members.first.id
      enrollee.coverage_start = Date.new(plan.year, 1, 1)
      enrollee.save
    end
    puts("Policy with #{Policy.last.enrollees.count} enrollees created.") unless Rails.env.test?
  end
end 

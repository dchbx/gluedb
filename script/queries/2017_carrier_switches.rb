# Finds all 2017 policies and if they are a carrier switch.

health_plans_2017 = Plan.where(year: 2017, coverage_type: "health").map(&:id)

dental_plans_2017 = Plan.where(year: 2017, coverage_type: "dental").map(&:id)

health_plans_2016 = Plan.where(year: 2016, coverage_type: "health").map(&:id)

dental_plans_2016 = Plan.where(year: 2016, coverage_type: "dental").map(&:id)

plans_2017 = health_plans_2017 + dental_plans_2017


policies_2017 = Policy.where({:enrollees => {"$elemMatch" => {:rel_code => "self",
                                                              :coverage_start => {"$gt" => Date.new(2016,12,31)}}}, 
                              :employer_id => {"$eq" => nil}, 
                              :plan_id => {"$in" => plans_2017}}).no_timeout

subscribers = policies_2017.map(&:subscriber).map(&:person).uniq!

timestamp = Time.now.strftime('%Y%m%d%H%M')

def check_carrier_switch(policy_set_1,policy_set_2)
  return false if policy_set_1.blank? || policy_set_2.blank?
  carriers_1 = policy_set_1.map(&:plan).map(&:carrier_id)
  carriers_2 = policy_set_2.map(&:plan).map(&:carrier_id)
  all_carriers = (carriers_1 + carriers_2).uniq
  if all_carriers.size > 1
    return true
  else
    return false
  end
end

def validate_2016_policies(policy_set)
  valid_policies = []
  policy_set.each do |policy|
    next if policy.policy_start.year != 2016
    if policy.terminated? && policy.policy_end == Date.new(2016,12,31)
      valid_policies << policy
    elsif policy.policy_end.blank?
      valid_policies << policy
    end
  end
  return valid_policies
end

def enrollment_kind_by_transaction(policy)
  transactions = policy.transaction_set_enrollments.to_a
  return "no transactions" if transactions.blank?
  if transactions.any?{|tse| tse.transaction_kind == "initial_enrollment"}
    return "initial enrollment"
  else
    return "maintenance"
  end
end

Caches::MongoidCache.with_cache_for(Carrier, Plan) do
  CSV.open("carrier_switch_renewals_#{timestamp}.csv","w") do |csv|
    csv << ["Carrier","Plan Name", "Plan HIOS ID","Effective Date","Termination Date","Subscriber Name","Subscriber HBX ID","Enrollee Count", "Enrollment Kind"]
    subscribers.each do |subscriber|
      hbx_ids = subscriber.members.map(&:hbx_member_id).compact
      next if subscriber.policies.size < 2
      health_policies_2016 = subscriber.policies.where(:plan_id => {"$in" => health_plans_2016}, :employer_id => {"$eq" => nil}).to_a.select{|policy| hbx_ids.include?(policy.subscriber.m_id) && !policy.canceled?}
      cleaned_health_policies_2016 = validate_2016_policies(health_policies_2016)
      health_policies_2017 = subscriber.policies.where(:plan_id => {"$in" => health_plans_2017}, :employer_id => {"$eq" => nil}).to_a.select{|policy| hbx_ids.include?(policy.subscriber.m_id) && !policy.canceled?}
      dental_policies_2016 = subscriber.policies.where(:plan_id => {"$in" => dental_plans_2016}, :employer_id => {"$eq" => nil}).to_a.select{|policy| hbx_ids.include?(policy.subscriber.m_id) && !policy.canceled?}
      cleaned_dental_policies_2016 = validate_2016_policies(dental_policies_2016)
      dental_policies_2017 = subscriber.policies.where(:plan_id => {"$in" => dental_plans_2017}, :employer_id => {"$eq" => nil}).to_a.select{|policy| hbx_ids.include?(policy.subscriber.m_id) && !policy.canceled?}
      health_carrier_switch = check_carrier_switch(cleaned_health_policies_2016,health_policies_2017)
      dental_carrier_switch = check_carrier_switch(cleaned_dental_policies_2016,dental_policies_2017)
      if health_carrier_switch == true
        health_policies = cleaned_health_policies_2016 + health_policies_2017
        health_policies.each do |policy|
          plan = Caches::MongoidCache.lookup(Plan, policy.plan_id) {policy.plan}
          carrier = Caches::MongoidCache.lookup(Carrier, policy.carrier_id) {policy.carrier}
          enrollment_kind = enrollment_kind_by_transaction(policy)
          csv << [carrier.name, plan.name, plan.hios_plan_id, policy.policy_start,policy.policy_end,subscriber.full_name,policy.subscriber.m_id,policy.enrollees.size, enrollment_kind]
        end # closes health policies loop
      end # closes health carrier switch
      if dental_carrier_switch == true
        dental_policies = cleaned_dental_policies_2016 + dental_policies_2017
        dental_policies.each do |policy|
          plan = Caches::MongoidCache.lookup(Plan, policy.plan_id) {policy.plan}
          carrier = Caches::MongoidCache.lookup(Carrier, policy.carrier_id) {policy.carrier}
          enrollment_kind = enrollment_kind_by_transaction(policy)
          csv << [carrier.name, plan.name, plan.hios_plan_id, policy.policy_start,policy.policy_end,subscriber.full_name,policy.subscriber.m_id,policy.enrollees.size, enrollment_kind]
        end
      end # closes dental carrier switch
    end # closes subscriber loop
  end # closes CSV
end # Closes MongoidCache
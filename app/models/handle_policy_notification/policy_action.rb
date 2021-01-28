module HandlePolicyNotification
  class PolicyAction
    include Virtus.model

    # If we have both a target policy and policy details,
    # it's an update.
    # If we have just policy details, it's a create
    attribute :action, String
    attribute :target_policy, Policy
    attribute :policy_details, ::HandlePolicyNotification::PolicyDetails
    attribute :member_detail_collection, Array[::HandlePolicyNotification::MemberDetails]
    attribute :employer_details, ::HandlePolicyNotification::EmployerDetails
    attribute :broker_details, ::HandlePolicyNotification::BrokerDetails
    attribute :plan_details, ::HandlePolicyNotification::PlanDetails
    attribute :member_changes, Array[::HandlePolicyNotification::MemberChange]
    attribute :transmit, Boolean, :default => true

    def transaction_id
      @transcation_id ||= TransactionIdGenerator.generate_bgn02_compatible_transaction_id
    end

    def new_policy_attributes
      base_attributes = {
        :plan => plan_details.found_plan,
        :eg_id => policy_details.enrollment_group_id,
        :pre_amt_tot => policy_details.pre_amt_tot,
        :tot_res_amt => policy_details.pre_amt_tot,
        :tot_emp_res_amt => policy_details.tot_emp_res_amt,
        :applied_aptc => policy_details.applied_aptc
      }
      add_broker_attribute(add_employer_attribute(base_attributes))
    end

    def add_employer_attribute(base_attributes)
      return base_attributes if employer_details.nil?
      base_attributes.merge({
        :employer => employer_details.found_employer
      })
    end

    def add_broker_attribute(base_attributes)
      return base_attributes if broker_details.nil?
      base_attributes.merge({
        :broker => broker_details.found_broker
      })
    end
  end
end

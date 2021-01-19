module ExternalEvents
  class ExternalPolicyAssistanceChange
    attr_reader :update_event
    attr_reader :policy
    attr_reader :policy_node

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    # p_record : Plan
    def initialize(policy, u_event)
      @policy = policy
      @update_event = u_event
      @policy_node = u_event.policy_cv
    end

    def extract_pre_amt_tot
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).premium_total_amount.strip.value)
    end

    def extract_tot_res_amt
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).total_responsible_amount.strip.value)
    end

    def extract_aptc_value
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return({}) if p_enrollment.blank?
      applied_aptc_val = Maybe.new(p_enrollment).individual_market.applied_aptc_amount.strip.value
      return nil if applied_aptc_val.blank?
      BigDecimal.new(applied_aptc_val)
    end

    def persist
      new_aptc_date = @update_event.subscriber_start
      tot_res_amt = extract_tot_res_amt
      pre_amt_tot = extract_pre_amt_tot
      aptc_amt = extract_aptc_value
      policy.set_aptc_effective_on(new_aptc_date, aptc_amt, pre_amt_tot, tot_res_amt)
      result = policy.save!
      Observers::PolicyUpdated.notify(policy)
      result
    end
  end
end

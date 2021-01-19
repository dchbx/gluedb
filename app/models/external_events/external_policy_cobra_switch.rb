module ExternalEvents
  class ExternalPolicyCobraSwitch
    attr_reader :policy_node
    attr_reader :existing_policy

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    # existing_policy : Policy
    def initialize(p_node, existing_policy)
      @policy_node = p_node
      @existing_policy = existing_policy
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

    def extract_cobra_eligibility_date
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      val = Maybe.new(p_enrollment).shop_market.cobra_eligibility_date.strip.value
      return nil if val.blank?
      Date.strptime(val, "%Y%m%d") rescue nil
    end

    def update_policy_information
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      tot_emp_res_amt_str = Maybe.new(p_enrollment).shop_market.total_employer_responsible_amount.strip.value
      tot_emp_res_amt = tot_emp_res_amt_str.blank? ? 0.00 : BigDecimal.new(tot_emp_res_amt_str)
      @existing_policy.update_attributes!({
        :cobra_eligibility_date => extract_cobra_eligibility_date,
        :pre_amt_tot => extract_pre_amt_tot,
        :tot_res_amt => extract_tot_res_amt,
        :tot_emp_res_amt => tot_emp_res_amt,
        :aasm_state => "submitted"
      })
      @existing_policy.hbx_enrollment_ids << extract_enrollment_group_id(@policy_node)
      result = @existing_policy.save!
      Observers::PolicyUpdated.notify(@existing_policy)
      result
    end

    def update_enrollee(enrollee_node)
      member_id = extract_member_id(enrollee_node)
      enrollee = @existing_policy.enrollees.detect { |en| en.m_id == member_id }
      if enrollee
        enrollee.ben_stat = "cobra"
        enrollee.emp_stat = "active"
        enrollee.coverage_end = nil
        enrollee.save!
      end
      @existing_policy.save!
    end

    def persist
      @policy_node.enrollees.each do |en|
        update_enrollee(en)
      end
      update_policy_information
      true
    end
  end
end

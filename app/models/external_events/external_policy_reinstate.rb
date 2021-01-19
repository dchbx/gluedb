module ExternalEvents
  class ExternalPolicyReinstate
    attr_reader :policy_node
    attr_reader :existing_policy

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    # existing_policy : Policy
    def initialize(p_node, existing_policy)
      @policy_node = p_node
      @existing_policy = existing_policy
    end

    def update_policy_information
      @existing_policy.update_attributes!({
        :aasm_state => "resubmitted",
        term_for_np: false
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
        enrollee.ben_stat = "active"
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

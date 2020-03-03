module EnrollmentAction
  class TerminatePolicyWithEarlierDate  < Base

    attr_accessor :existing_policy

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false unless chunk.first.is_termination?
      chunk.first.is_reterm_with_earlier_date?
    end

    def persist
      @existing_policy = Policy.where(hbx_enrollment_ids: termination.policy_cv.previous_policy_id).first
      if existing_policy.present? && existing_policy.terminate_as_of(termination.subscriber_end)
        existing_policy.hbx_enrollment_ids << termination.hbx_enrollment_id
        existing_policy.save!
      else
        false
      end
    end

    def publish
      amqp_connection = termination.event_responder.connection
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end

      reinstate_action_helper = ActionPublishHelper.new(termination.event_xml)
      reinstate_action_helper.set_policy_id(existing_policy.eg_id)
      reinstate_action_helper.set_member_starts(member_date_map)
      reinstate_action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      reinstate_action_helper.keep_member_ends([])

      if existing_policy.carrier.requires_reinstate_for_earlier_termination                 # send reinstate to nfp & all carriers except carefirst.
        publish_result, publish_errors = publish_edi(amqp_connection, reinstate_action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
      else                                                                                   # send reinstate to nfp for carefirst enrollment.
        publish_result, publish_errors = publish_edi(amqp_connection, reinstate_action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id, false)
      end

      unless publish_result
        return [publish_result, publish_errors]
      end

      termiantion_action_helper = ActionPublishHelper.new(termination.event_xml)
      termiantion_action_helper.set_policy_id(existing_policy.eg_id)
      termiantion_action_helper.set_member_starts(member_date_map)
      termiantion_action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")  # sends termination to nfp & carriers.

      publish_edi(amqp_connection, termiantion_action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
    end
  end
end

module EnrollmentAction
  class ConcurrentPolicyCancelAndTerm < Base

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false unless chunk.first.is_termination?
      is_concurrent_cancel_term_policy?(chunk)
    end

    def self.is_concurrent_cancel_term_policy?(chunk)
      return false unless chunk.first.is_cancel?
      existing_policy = chunk.first.existing_policy
      return false unless (existing_policy.present? && existing_policy.policy_start < chunk.first.subscriber_start)

      active_enrollees = existing_policy.enrollees.reject { |e| e.relationship_status_code == "self" || e.canceled? || e.terminated? }
      if active_enrollees.any? { |m| chunk.first.all_member_ids.include?(m.m_id) }
        active_enrollees.any? do |enrollee|
          (enrollee.coverage_start == chunk.first.subscriber_end || enrollee.coverage_start < chunk.first.subscriber_start)
        end
      else
        true
      end
    end

    def persist
      if termination.existing_policy
        termination_date =  termination.subscriber_end - 1.day
        policy_to_term = termination.existing_policy
        return policy_to_term.terminate_as_of(termination_date)
      else
        false
      end
    end

    def publish
      existing_policy = termination.existing_policy
      member_date_map = {}
      member_end_date_map = {}
      dropped_dependents = []
      terminated_dependents = []

      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
        member_end_date_map[en.m_id] = en.coverage_end
        if termination.all_member_ids.include?(en.m_id)
          dropped_dependents << en.m_id if en.coverage_start == en.coverage_end
          terminated_dependents << en.m_id if en.coverage_end > en.coverage_start
        end
      end

      if dropped_dependents.present?
        cancellation_helper = ActionPublishHelper.new(termination.event_xml)
        cancellation_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_terminate")
        cancellation_helper.set_policy_id(existing_policy.eg_id)
        cancellation_helper.set_member_starts(member_date_map)
        cancellation_helper.filter_affected_members(dropped_dependents)
        cancellation_helper.keep_member_ends(dropped_dependents)
        cancellation_helper.recalculate_premium_totals_excluding_dropped_dependents(dropped_dependents)

        amqp_connection = termination.event_responder.connection
        publish_result, publish_errors = publish_edi(amqp_connection, cancellation_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)

        unless publish_result
          return [publish_result, publish_errors]
        end
      end

      if terminated_dependents.present?
        termination_helper = ActionPublishHelper.new(termination.event_xml)
        termination_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
        termination_helper.set_policy_id(existing_policy.eg_id)
        termination_helper.set_member_starts(member_date_map)
        termination_helper.filter_affected_members(terminated_dependents)
        termination_helper.filter_enrollee_members(terminated_dependents)
        termination_helper.set_member_end_date(member_end_date_map)
        termination_helper.recalculate_premium_totals_excluding_dropped_dependents(terminated_dependents)

        amqp_connection = termination.event_responder.connection
        publish_edi(amqp_connection, termination_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
      end
    end
  end
end
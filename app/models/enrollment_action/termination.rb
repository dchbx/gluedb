module EnrollmentAction
  class Termination < Base
    extend ReinstatementComparisonHelper
    include NotificationExemptionHelper

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false unless reinstate_capable_carrier?(chunk.first)
      chunk.first.is_termination?
    end

    # Remember, we only have an @termination, no @action item
    def persist
      if termination.existing_policy
        policy_to_term = termination.existing_policy
        unless policy_to_term.is_shop?
          policy_to_term.reload
          return false if policy_to_term.canceled?
        end
        existing_npt = policy_to_term.term_for_np
        result = policy_to_term.terminate_as_of(termination.subscriber_end)
        if termination.existing_policy.carrier.termination_cancels_renewal
          termination.renewal_policies_to_cancel.each do |pol|
            pol.cancel_via_hbx!
          end
        end
        unless termination_event_exempt_from_notification?(policy_to_term, termination.subscriber_end, true, existing_npt)
          Observers::PolicyUpdated.notify(policy_to_term)
        end
        return result
      end
      true
    end

    def publish
      existing_policy = termination.existing_policy
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      action_helper = ActionPublishHelper.new(termination.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      action_helper.set_policy_id(existing_policy.eg_id)
      action_helper.set_member_starts(member_date_map)
      amqp_connection = termination.event_responder.connection
      publish_edi(amqp_connection, action_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
    end
  end
end

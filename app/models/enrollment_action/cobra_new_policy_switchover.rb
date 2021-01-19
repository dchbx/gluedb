module EnrollmentAction
  class CobraNewPolicySwitchover < Base
    extend ReinstatementComparisonHelper
    extend PlanComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless chunk.first.is_termination?
      return false unless chunk.last.is_cobra?
      return false if chunk.last.is_termination?
      return false if carriers_are_different?(chunk)
      return false if reinstate_capable_carrier?(chunk.last)
      start_and_end_dates_align(chunk)
    end

    def persist
      return false if check_already_exists
      members = action.policy_cv.enrollees.map(&:member)
      members_persisted = members.map do |mem|
        em = ExternalEvents::ExternalMember.new(mem)
        em.persist
      end
      unless members_persisted.all?
        return false
      end
      #cobra_reinstate = true
      ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, true, market_from_payload: action.kind)
      return false unless ep.persist
      policy_to_term = termination.existing_policy
      result = policy_to_term.terminate_as_of(termination.subscriber_end)
      Observers::PolicyUpdated.notify(policy_to_term)
      result
    end

    def publish
      existing_policy = termination.existing_policy
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      term_connection = termination.event_responder.connection
      term_helper = ActionPublishHelper.new(termination.event_xml)
      term_helper.set_event_action("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      term_helper.set_policy_id(existing_policy.eg_id)
      term_helper.set_member_starts(member_date_map)
      publish_result, publish_errors = publish_edi(term_connection, term_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
      unless publish_result
        return [publish_result, publish_errors]
      end
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

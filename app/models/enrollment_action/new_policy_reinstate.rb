module EnrollmentAction
  class NewPolicyReinstate < Base
    extend ReinstatementComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false if chunk.first.is_cobra?
      return false unless is_continuation_of_coverage_event?(chunk.first)
      return false if reinstate_capable_carrier?(chunk.first) #CF is the only one that isn't capable, across both exchanges
      any_market_reinstatement_candidates(chunk.first).any?
    end

    def persist
      members = action.policy_cv.enrollees.map(&:member)
        members_persisted = members.map do |mem|
          em = ExternalEvents::ExternalMember.new(mem)
          em.persist
        end
        unless members_persisted.all?
          return false
        end
        #cobra_reinstate = true
        ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, false, policy_reinstate: true)
        ep.persist
    end

    def publish
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

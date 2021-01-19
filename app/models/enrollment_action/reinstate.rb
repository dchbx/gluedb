module EnrollmentAction
  class Reinstate < Base
    extend ReinstatementComparisonHelper
    include ReinstatementComparisonHelper

    attr_accessor :existing_policy
    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false if chunk.first.is_cobra?
      return false unless is_continuation_of_coverage_event?(chunk.first)
      any_market_reinstatement_candidates(chunk.first).any?
    end

    def persist
      @existing_policy = any_market_reinstatement_candidates(action).first
      policy_updater = ExternalEvents::ExternalPolicyReinstate.new(action.policy_cv, @existing_policy)
      policy_updater.persist
    end

    def publish
      member_date_map = {}
      @existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_policy_id(@existing_policy.eg_id)
      action_helper.set_member_starts(member_date_map)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

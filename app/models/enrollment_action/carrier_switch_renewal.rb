module EnrollmentAction
  class CarrierSwitchRenewal < Base
    extend RenewalComparisonHelper
    include NotificationExemptionHelper

    attr_accessor :terminated_policy_information

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false if chunk.first.is_passive_renewal?
      renewal_candidates = other_carrier_renewal_candidates(chunk.first)
      !renewal_candidates.empty?
    end

    def persist
      return false if check_already_exists
      termination_candidates = self.class.other_carrier_renewal_candidates(action)
      @terminated_policy_information = termination_candidates.map do |t_pol|
        [t_pol, t_pol.active_member_ids]
      end
      termination_results = termination_candidates.map do |rc|
        existing_npt = rc.term_for_np
        term_result = rc.terminate_as_of(action.subscriber_start - 1.day)
        unless termination_event_exempt_from_notification?(rc, action.subscriber_start - 1.day, true, existing_npt)
          Observers::PolicyUpdated.notify(rc)
        end
        term_result
      end
      return false unless termination_results.all?
      other_carrier_renewal_candidates = self.class.other_carrier_renewal_candidates(action)
      members = action.policy_cv.enrollees.map(&:member)
      members_persisted = members.map do |mem|
        em = ExternalEvents::ExternalMember.new(mem)
        em.persist
      end
      unless members_persisted.all?
        return false
      end
      ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, action.is_cobra?, market_from_payload: action.kind)
      ep.persist
    end

    def publish
      amqp_connection = action.event_responder.connection
      @terminated_policy_information.each do |tpi|
        pol, a_member_ids = tpi
        writer = ::EnrollmentAction::EnrollmentTerminationEventWriter.new(pol, a_member_ids)
        term_event_xml = writer.write("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#terminate_enrollment")
        employer = pol.employer
        employer_hbx_id = employer.blank? ? nil : employer.hbx_id
        term_action_helper = EnrollmentAction::ActionPublishHelper.new(term_event_xml)
        publish_edi(amqp_connection, term_action_helper.to_xml, pol.eg_id, employer_hbx_id)
      end
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#initial")
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

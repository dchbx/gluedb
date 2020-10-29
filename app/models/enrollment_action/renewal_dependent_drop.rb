module EnrollmentAction
  class RenewalDependentDrop < Base
    extend RenewalComparisonHelper
    include NotificationExemptionHelper

    attr_accessor :terminated_policy_information

    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if chunk.first.is_termination?
      return false if chunk.first.is_passive_renewal?
      renewal_candidates = same_carrier_renewal_candidates(chunk.first)
      return false if renewal_candidates.empty?
      renewal_dependents_dropped?(renewal_candidates.first, chunk.first)
    end

    def dropped_dependents
      renewal_candidates = self.class.same_carrier_renewal_candidates(action)
      renewal_candidates.first.active_member_ids - action.all_member_ids
    end

    def persist
      dropped_dependent_ids = dropped_dependents
      termination_info = []
      self.class.same_carrier_renewal_candidates(action).each do |rc|
        termination_info << [rc, dropped_dependent_ids]
        dependent_drop_results = dropped_dependent_ids.map do |drop_d_id|
          rc.terminate_member_id_on(drop_d_id, action.subscriber_start - 1.day)
        end
        return false unless dependent_drop_results.all?
        unless termination_event_exempt_from_notification?(rc, action.subscriber_start - 1.day)
          Observers::PolicyUpdated.notify(rc)
        end
      end
      @terminated_policy_information = termination_info
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
        pol.reload
        writer = ::EnrollmentAction::EnrollmentTerminationEventWriter.new(pol, (pol.active_member_ids + a_member_ids).uniq)
        term_event_xml = writer.write("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#change_member_terminate")
        employer = pol.employer
        employer_hbx_id = employer.blank? ? nil : employer.hbx_id
        term_action_helper = EnrollmentAction::ActionPublishHelper.new(term_event_xml)
        term_action_helper.filter_affected_members(a_member_ids)
        publish_edi(amqp_connection, term_action_helper.to_xml, pol.eg_id, employer_hbx_id)
      end
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      if action.renewal_cancel_policy.present? && action.existing_policy.carrier.canceled_renewal_causes_new_coverage
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#initial")
      else
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#active_renew")
      end
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

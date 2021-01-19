module EnrollmentAction
  class PlanChange < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include TerminationDateHelper
    include RenewalComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false if same_plan?(chunk)
      (!carriers_are_different?(chunk)) && !dependents_changed?(chunk)
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
      ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, action.is_cobra?, market_from_payload: action.kind)
      return false unless ep.persist
      policy_to_term = termination.existing_policy
      termination_date = select_termination_date
      result = policy_to_term.terminate_as_of(termination_date)
      Observers::PolicyUpdated.notify(policy_to_term)
      result
    end

    def publish
      event_action = "urn:openhbx:terms:v1:enrollment#change_product"
      if !action.is_shop?
        if same_carrier_renewal_candidates(action).any?
          subscriber_start = extract_enrollee_start(action.subscriber)
          now_time = Time.now
          if !subscriber_start.blank?
            if (subscriber_start.year == (now_time.year + 1)) && (subscriber_start.day == 1) && (subscriber_start.month == 1)
              if (now_time.month < 12) || ((now_time.month == 12) && (now_time.day < 21))
                event_action = "urn:openhbx:terms:v1:enrollment#active_renew"
              end
            end
          end
        end
      end
      amqp_connection = action.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      action_helper.set_event_action(event_action)
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

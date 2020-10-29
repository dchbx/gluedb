module EnrollmentAction
  class PlanChangeDependentAdd < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include TerminationDateHelper
    include RenewalComparisonHelper

    attr_accessor :plan_change_dep_adding_to_renewal

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false if same_plan?(chunk)
      (!carriers_are_different?(chunk)) && dependents_added?(chunk)
    end

    def added_dependents
      action.all_member_ids - termination.all_member_ids
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
      @plan_change_dep_adding_to_renewal = action.existing_plan.carrier.plan_change_renewal_dependent_add_transmitted_as_renewal && action.plan_change_dep_add_or_drop_to_renewal_policy?(renewal_candidate, termination.existing_policy)
      termination_date = select_termination_date
      policy_to_term = termination.existing_policy
      result = policy_to_term.terminate_as_of(termination_date)
      Observers::PolicyUpdated.notify(policy_to_term)
      result
    end

    def renewal_candidate
      same_carrier_renewal_candidates(action).first
    end

    def publish
      amqp_connection = termination.event_responder.connection
      action_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      if plan_change_dep_adding_to_renewal
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#auto_renew")
      else
        action_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_product_member_add")
        action_helper.filter_affected_members(added_dependents)
      end
      action_helper.keep_member_ends([])
      publish_edi(amqp_connection, action_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
    end
  end
end

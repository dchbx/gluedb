module EnrollmentAction
  class DependentAdd < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    include RenewalComparisonHelper

    attr_accessor :dep_adding_to_renewal

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless same_plan?(chunk)
      dependents_added?(chunk)
    end

    def added_dependents
      action.all_member_ids - termination.all_member_ids
    end

    def renewal_candidate
      same_carrier_renewal_candidates(action).first
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
      policy_to_change = termination.existing_policy
      @dep_adding_to_renewal = policy_to_change.carrier.renewal_dependent_add_transmitted_as_renewal && action.dep_add_or_drop_to_renewal_policy?(renewal_candidate, policy_to_change)
      if @dep_adding_to_renewal
        return false if check_already_exists
        ep = ExternalEvents::ExternalPolicy.new(action.policy_cv, action.existing_plan, action.is_cobra?, market_from_payload: action.kind)
        return false unless ep.persist
        policy_to_change.cancel_via_hbx!
        true
      else
        # Add new hbx_enrollment_id to policy
        policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
        policy_to_change.save!
        pol_updater = ExternalEvents::ExternalPolicyMemberAdd.new(
            policy_to_change,
            action.policy_cv,
            added_dependents)
        pol_updater.persist
        true
      end
    end

    def publish
      amqp_connection = termination.event_responder.connection
      policy_to_change = termination.existing_policy
      change_publish_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      if @dep_adding_to_renewal
        change_publish_helper.set_event_action("urn:openhbx:terms:v1:enrollment#auto_renew")
        change_publish_helper.keep_member_ends([])
        publish_edi(amqp_connection, change_publish_helper.to_xml, action.hbx_enrollment_id, action.employer_hbx_id)
      else
        member_date_map = {}
        policy_to_change.enrollees.each do |en|
          member_date_map[en.m_id] = en.coverage_start
        end
        change_publish_helper.set_policy_id(policy_to_change.eg_id)
        change_publish_helper.set_member_starts(member_date_map)
        change_publish_helper.filter_affected_members(added_dependents)
        change_publish_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_add")
        change_publish_helper.keep_member_ends([])
        publish_edi(amqp_connection, change_publish_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
      end
    end
  end
end

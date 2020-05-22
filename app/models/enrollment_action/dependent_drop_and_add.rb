module EnrollmentAction
  class DependentDropAndAdd < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper

    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless same_plan?(chunk)
      dependents_added_and_dropped?(chunk)
    end

    def added_dependents
      action.all_member_ids - termination.all_member_ids
    end

    def dropped_dependents
      termination.all_member_ids - action.all_member_ids
    end

    def persist
      policy_to_change = termination.existing_policy
      policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
      policy_to_change.save
      pol_updater = ExternalEvents::ExternalPolicyMemberDrop.new(policy_to_change, termination.policy_cv, dropped_dependents)
      pol_updater.use_totals_from(action.policy_cv)
      pol_updater.persist

      members = action.policy_cv.enrollees.map(&:member)
      members_persisted = members.map do |mem|
        em = ExternalEvents::ExternalMember.new(mem)
        em.persist
      end
      unless members_persisted.all?
        return false
      end
      policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id unless policy_to_change.hbx_enrollment_ids.include?(action.hbx_enrollment_id)
      policy_to_change.save!
      pol_updater = ExternalEvents::ExternalPolicyMemberAdd.new(policy_to_change,action.policy_cv,added_dependents)
      pol_updater.persist
    end

    def publish
      amqp_connection = termination.event_responder.connection
      existing_policy = termination.existing_policy
      member_date_map = {}
      existing_policy.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      termination_helper = ActionPublishHelper.new(termination.event_xml)
      termination_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_terminate")
      termination_helper.set_policy_id(existing_policy.eg_id)
      termination_helper.set_member_starts(member_date_map)
      termination_helper.filter_affected_members(dropped_dependents)
      termination_helper.replace_premium_totals(action.event_xml)
      termination_helper.keep_member_ends(dropped_dependents)
      termination_helper.swap_qualifying_event(action.event_xml)
      publish_edi(amqp_connection, termination_helper.to_xml, existing_policy.eg_id, termination.employer_hbx_id)

      policy_to_change = termination.existing_policy
      member_date_map = {}
      policy_to_change.enrollees.each do |en|
        member_date_map[en.m_id] = en.coverage_start
      end
      change_publish_helper = EnrollmentAction::ActionPublishHelper.new(action.event_xml)
      change_publish_helper.set_policy_id(policy_to_change.eg_id)
      change_publish_helper.filter_affected_members(added_dependents)
      change_publish_helper.set_event_action("urn:openhbx:terms:v1:enrollment#change_member_add")
      change_publish_helper.set_member_starts(member_date_map)
      change_publish_helper.keep_member_ends([])
      publish_edi(amqp_connection, change_publish_helper.to_xml, termination.hbx_enrollment_id, termination.employer_hbx_id)
    end

  end
end
module EnrollmentAction
  class CarefirstTermination < Base
    extend ReinstatementComparisonHelper
    
    def self.qualifies?(chunk)
      return false if chunk.length > 1
      return false if reinstate_capable_carrier?(chunk.first)
      chunk.first.is_termination?
    end

    # Remember, we only have an @terminate_enrollmenttion, no @action item
    def persist
      if termination.existing_policy
        policy_to_term = termination.existing_policy
        unless policy_to_term.is_shop?
          policy_to_term.reload
          return false if policy_to_term.canceled?
        end
        # Is this even a cancellation, if so, check for custom NPT behaviour,
        # otherwise do nothing

        if termination.is_cancel?
          begin
            canceled_policy_m_id = policy_to_term.subscriber.m_id
            canceled_policy_plan_id = policy_to_term.plan_id
            canceled_policy_carrier_id = policy_to_term.carrier_id
            canceled_policy_test_date = (policy_to_term.policy_start - 1.day)
            pols = Person.where(authority_member_id: canceled_policy_m_id ).first.policies
            pols.each do |pol|
              if (pol.aasm_state == "terminated" && pol.employer_id == nil)
                if (pol.policy_end == canceled_policy_test_date && pol.plan_id == canceled_policy_plan_id && pol.carrier_id == canceled_policy_carrier_id)
                  unless pol.versions.empty?
                    last_version_npt = pol.versions.last.term_for_np
                    pol.update_attributes!(term_for_np: last_version_npt)
                  end
                end
              end
            end
          rescue Exception => e
            puts e.to_s
          end
        end
        policy_to_term.terminate_as_of(termination.subscriber_end)
        if termination.existing_policy.carrier.termination_cancels_renewal
          termination.renewal_policies_to_cancel.each do |pol|
            pol.cancel_via_hbx!
          end
        end
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

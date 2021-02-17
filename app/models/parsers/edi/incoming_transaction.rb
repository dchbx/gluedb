module Parsers
  module Edi
    class IncomingTransaction
      attr_reader :errors

      def self.from_etf(etf, i_cache)
        incoming_transaction = new(etf)

        subscriber_policy_loop = etf.subscriber_loop.policy_loops.first

        find_policy = FindPolicy.new(incoming_transaction)
        policy = find_policy.by_subkeys({
          :eg_id => subscriber_policy_loop.eg_id,
          :hios_plan_id => subscriber_policy_loop.hios_id
        })

        person_loop_validator = PersonLoopValidator.new
        etf.people.each do |person_loop|
          person_loop_validator.validate(person_loop, incoming_transaction, policy)
        end

        policy_loop_validator = PolicyLoopValidator.new
        policy_loop_validator.validate(subscriber_policy_loop, incoming_transaction)

        incoming_transaction
      end

      def initialize(etf)
        @etf = etf
        @errors = []
      end

      def valid?
        @errors.empty?
      end

      def import
        return unless valid?
        is_policy_term = false
        is_policy_cancel = false
        is_non_payment = false
        old_npt_flag = @policy.term_for_np
        @etf.people.each do |person_loop|
          begin
            enrollee = @policy.enrollee_for_member_id(person_loop.member_id)

            policy_loop = person_loop.policy_loops.first

            enrollee.c_id = person_loop.carrier_member_id
            enrollee.cp_id = policy_loop.id

            if(!@etf.is_shop? && policy_loop.action == :stop )
              enrollee.coverage_status = 'inactive'
              enrollee.coverage_end = policy_loop.coverage_end
              if enrollee.subscriber?
                is_non_payment = person_loop.non_payment_change?
                if enrollee.coverage_start == enrollee.coverage_end
                  is_policy_cancel = true
                  policy_end_date = enrollee.coverage_end
                  enrollee.policy.aasm_state = "canceled"
                  enrollee.policy.term_for_np = is_non_payment
                  enrollee.policy.save
                else
                  is_policy_term = true
                  policy_end_date = enrollee.coverage_end
                  enrollee.policy.aasm_state = "terminated"
                  enrollee.policy.term_for_np = is_non_payment
                  enrollee.policy.save
                end
              end
            end
          rescue Exception
            puts @policy.eg_id
            puts person_loop.member_id
            raise $!
          end
        end
        save_val = @policy.save
        unless exempt_from_notification?(@policy, is_policy_cancel, is_policy_term, old_npt_flag == is_non_payment)
          Observers::PolicyUpdated.notify(@policy)
        end

        if is_policy_term || is_policy_cancel
          @policy.cancel_ivl_renewal
        end

        if is_policy_term
          # Broadcast the term
          reason_headers = if is_non_payment
                             {:qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"}
                           else
                             {}
                           end
          Amqp::EventBroadcaster.with_broadcaster do |eb|
            eb.broadcast(
              {
                :routing_key => "info.events.policy.terminated",
                :headers => {
                  :resource_instance_uri => @policy.eg_id,
                  :event_effective_date => @policy.policy_end.strftime("%Y%m%d"),
                  :hbx_enrollment_ids => JSON.dump(@policy.hbx_enrollment_ids)
                }.merge(reason_headers)
              },
              "")
          end
        elsif is_policy_cancel
          # Broadcast the cancel
          reason_headers = if is_non_payment
                             {:qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"}
                           else
                             {}
                           end
          Amqp::EventBroadcaster.with_broadcaster do |eb|
            eb.broadcast(
              {
                :routing_key => "info.events.policy.canceled",
                :headers => {
                  :resource_instance_uri => @policy.eg_id,
                  :event_effective_date => @policy.policy_end.strftime("%Y%m%d"),
                  :hbx_enrollment_ids => JSON.dump(@policy.hbx_enrollment_ids)
                }.merge(reason_headers)
              },
              "")
          end
        end
        save_val
      end

      def exempt_from_notification?(policy, is_cancel, is_term, npt_changed)
        return false if is_cancel
        return false if npt_changed
        return false unless is_term
        (policy.policy_end.day == 31) && (policy.policy_end.month == 12)
      end

      def policy_found(policy)
        @policy = policy
      end

      def termination_with_no_end_date(details)
        @errors << "File is a termination, but no or invalid end date is provided for a member: Member #{details[:member_id]}, Coverage End: #{details[:coverage_end_string]}"
      end

      def coverage_end_before_coverage_start(details)
        @errors << "Coverage end before coverage start: Member #{details[:member_id]}, coverage_start: #{details[:coverage_start]}, coverage_end: #{details[:coverage_end]}"
      end

      def term_or_cancel_for_2014_individual(details)
        @errors << "Cancel/Term issued on 2014 policy. Member #{details[:member_id]}, end date #{details[:date]}"
      end

      def effectuation_date_mismatch(details)
        @errors << "Effectuation date mismatch: member #{details[:member_id]}, enrollee start: #{details[:policy]}, effectuation start: #{details[:effectuation]}"
      end

      def indeterminate_policy_expiration(details)
        @errors << "Could not determine natural policy expiration date: member #{details[:member_id]}"
      end

      def termination_date_after_expiration(details)
        @errors << "Termination date after natural policy expiration: member #{details[:member_id]}, coverage end: #{details[:coverage_end]}, expiration_date: #{details[:expiration_date]}"
      end

      def policy_not_found(subkeys)
        @errors << "Policy not found. Details: #{subkeys}"
      end

      def plan_found(plan)
        @plan = plan
      end

      def plan_not_found(hios_id)
        @errors << "Plan not found. (hios id: #{hios_id})"
      end

      def carrier_found(carrier)
        @carrier = carrier
      end

      def carrier_not_found(fein)
        @errors << "Carrier not found. (fein: #{fein})"
      end

      def found_carrier_member_id(id)
      end

      def missing_carrier_member_id(person_loop)
        policy_loop = person_loop.policy_loops.first
        if(!policy_loop.canceled?)
          @errors << "Missing Carrier Member ID."
        end
      end

      def no_such_member(id)
        @errors << "Member not found in policy: #{id}"
      end

      def found_carrier_policy_id(id)
      end

      def missing_carrier_policy_id
        @errors << "Missing Carrier Policy ID."
      end

      def policy_id
        @policy ? @policy._id : nil
      end

      def carrier_id
        @carrier ? @carrier._id : nil
      end

      def employer_id
        @employer ? @employer._id : nil
      end
    end
  end
end

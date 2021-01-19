module EnrollmentAction
  class Base
    attr_reader :action
    attr_reader :termination
    attr_reader :errors

    def initialize(term, init)
      @termination = term
      @action = init
      @errors = ActiveModel::Errors.new(self)
    end

    def update_business_process_history(entry)
      if @termination
        @termination.update_business_process_history(entry)
      end
      if @action
        @action.update_business_process_history(entry)
      end
    end

    def self.select_action_for(chunk)
      selected_action = [
        ::EnrollmentAction::SimpleRenewal,
        ::EnrollmentAction::PassiveRenewal,
        ::EnrollmentAction::ActiveRenewal,
        ::EnrollmentAction::NewPolicyReinstate,
        ::EnrollmentAction::Reinstate,
        ::EnrollmentAction::CarrierSwitch,
        ::EnrollmentAction::CarrierSwitchRenewal,
        ::EnrollmentAction::SimpleProductChange,
        ::EnrollmentAction::MarketChange,
        ::EnrollmentAction::DependentDropAndAdd,
        ::EnrollmentAction::DependentAdd,
        ::EnrollmentAction::DependentDrop,
        ::EnrollmentAction::PlanChangeDependentDropAndAdd,
        ::EnrollmentAction::PlanChange,
        ::EnrollmentAction::PlanChangeDependentAdd,
        ::EnrollmentAction::PlanChangeDependentDrop,
        ::EnrollmentAction::RenewalDependentAdd,
        ::EnrollmentAction::RenewalDependentDrop,
        ::EnrollmentAction::CobraNewPolicySwitchover,
        ::EnrollmentAction::CobraNewPolicyReinstate,
        ::EnrollmentAction::CobraSwitchover,
        ::EnrollmentAction::CobraReinstate,
        ::EnrollmentAction::AssistanceChange,
        ::EnrollmentAction::InitialEnrollment,
        ::EnrollmentAction::TerminatePolicyWithEarlierDate,
        ::EnrollmentAction::ConcurrentPolicyCancelAndTerm,
        ::EnrollmentAction::CarefirstTermination,
        ::EnrollmentAction::Termination,
        ::EnrollmentAction::ReselectionOfExistingCoverage
      ].detect { |kls| kls.qualifies?(chunk) }

      if selected_action
        puts selected_action.inspect
        selected_action.construct(chunk)
      else
        batch_id = SecureRandom.uuid
        chunk.each_with_index do |c,idx|
          c.no_event_found!(batch_id, idx)
        end
        nil
      end
    end

    def self.construct(chunk)
      term = chunk.detect { |c| c.is_termination? }
      action = chunk.detect { |c| !c.is_termination? }
      self.new(term, action)
    end

    # Check if an enrollment already exists - if it does and you don't want to send out a new transaction, call this method.
    def check_already_exists
      if @action && action.existing_policy
        errors.add(:action, "enrollment already exists")
        return true
      end
      return false
    end

    # When implemented in a subclass, return true on successful persistance of
    # the action - otherwise return false.
    def persist
      raise NotImplementedError, "subclass responsibility"
    end

    # Performing publishing.  On failure, use the enrollment event
    # notifications to log the errors.
    def publish
      raise NotImplementedError, "subclass responsibility"
    end

    def drop_not_yet_implemented!
      idx = 0
      batch_id = SecureRandom.uuid
      if @termination
        idx = idx + 1
        @termination.drop_not_yet_implemented!(self.class.name.to_s, batch_id, idx)
      end
      if @action
        @action.drop_not_yet_implemented!(self.class.name.to_s, batch_id, idx)
      end
    end

    def persist_failed!(persist_errors)
      idx = 0
      batch_id = SecureRandom.uuid
      if @termination
        idx = idx + 1
        @termination.persist_failed!(self.class.name.to_s, persist_errors, batch_id, idx)
      end
      if @action
        @action.persist_failed!(self.class.name.to_s, persist_errors, batch_id, idx)
      end
    end

    def publish_failed!(publish_errors)
      idx = 0
      batch_id = SecureRandom.uuid
      if @termination
        idx = idx + 1
        @termination.publish_failed!(self.class.name.to_s, publish_errors, batch_id, idx)
      end
      if @action
        @action.publish_failed!(self.class.name.to_s, publish_errors, batch_id, idx)
      end
    end

    def flow_successful!
      idx = 0
      batch_id = SecureRandom.uuid
      if @termination
        @termination.flow_successful!(self.class.name.to_s, batch_id, idx)
      end
      if @action
        @action.flow_successful!(self.class.name.to_s, batch_id, idx)
      end
    end

    # Errors stuff for ActiveModel::Errors
    def read_attribute_for_validation(attr)
      send(attr)
    end

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def self.lookup_ancestors
      [self]
    end

    def publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id, send_to_carrier = true, send_to_payment_processor = true)
      publisher = Publishers::TradingPartnerEdi.new(amqp_connection, event_xml)
      publish_result = false

      if send_to_carrier
        publish_result = publisher.publish
      else
        publish_result = true
      end

      if publish_result
         publisher2 = Publishers::TradingPartnerLegacyCv.new(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
         if send_to_payment_processor
           unless publisher2.publish
             return [false, publisher2.errors.to_hash]
           end
         end
      end
      [publish_result, publisher.errors.to_hash]
    end
  end
end

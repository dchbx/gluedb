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
        ::EnrollmentAction::PassiveRenewal,
        ::EnrollmentAction::ActiveRenewal,
        ::EnrollmentAction::CarrierSwitch,
        ::EnrollmentAction::CarrierSwitchRenewal,
        ::EnrollmentAction::DependentAdd,
        ::EnrollmentAction::DependentDrop,
        ::EnrollmentAction::PlanChange,
        ::EnrollmentAction::PlanChangeDependentAdd,
        ::EnrollmentAction::PlanChangeDependentDrop,
        ::EnrollmentAction::RenewalDependentAdd,
        ::EnrollmentAction::RenewalDependentDrop,
        ::EnrollmentAction::InitialEnrollment,
        ::EnrollmentAction::Termination
      ].detect { |kls| kls.qualifies?(chunk) }
      
      if selected_action
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
      if @termination
        @termination.flow_successful!(self.class.name.to_s)
      end
      if @action
        @action.flow_successful!(self.class.name.to_s)
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

    def publish_edi(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
      publisher = Publishers::TradingPartnerEdi.new(amqp_connection, event_xml)
      publish_result = false
      publish_result = publisher.publish
      if publish_result
         publisher2 = Publishers::TradingPartnerLegacyCv.new(amqp_connection, event_xml, hbx_enrollment_id, employer_id)
         unless publisher2.publish
           return [false, publisher2.errors.to_hash]
         end
      end
      [publish_result, publisher.errors.to_hash]
    end
  end
end
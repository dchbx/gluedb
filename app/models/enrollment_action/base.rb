module EnrollmentAction
  class Base
    attr_reader :action
    attr_reader :termination

    def initialize(term, init)
      @termination = term
      @action = init
    end


    def self.select_action_for(chunk)
      [
        ::EnrollmentAction::PassiveRenewal,
        ::EnrollmentAction::ActiveRenewal,
        ::EnrollmentAction::CarrierSwitch,
        ::EnrollmentAction::CarrierSwitchRenewal,
        ::EnrollmentAction::DependentAdd,
        ::EnrollmentAction::DependentDrop,
        ::EnrollmentAction::InitialEnrollment,
        ::EnrollmentAction::PlanChange,
        ::EnrollmentAction::PlanChangeDependentAdd,
        ::EnrollmentAction::PlanChangeDependentDrop,
        ::EnrollmentAction::RenewalDependentAdd,
        ::EnrollmentAction::RenewalDependentDrop
      ].detect { |kls| kls.qualifies?(chunk) }.construct(chunk)
    end

    def self.construct(chunk)
      term = chun.detect { chunk.is_termination? }
      action = chun.detect { !chunk.is_termination? }
      self.class.new(term, init)
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
      if @termination
        @termination.drop_not_yet_implemented!(self.class.name.to_s)
      end
      if @action
        @action.drop_not_yet_implemented!(self.class.name.to_s)
      end
    end
  end
end

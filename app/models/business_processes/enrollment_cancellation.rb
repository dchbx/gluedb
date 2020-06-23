module BusinessProcesses
  class EnrollmentCancellation
    attr_accessor :hbx_enrollment_id
    attr_accessor :termination_date
    attr_accessor :affected_member_ids
    attr_accessor :member_ids
    attr_accessor :transmit

    def initialize(eg_id, a_members = [])
      @hbx_enrollment_id = eg_id
      @affected_member_ids = a_members
      @member_ids = policy.active_member_ids
      @transmit = true
    end

    def transmit?; @transmit; end

    def policy
      @policy ||= Policy.where(:eg_id => @hbx_enrollment_id).first
    end

    def execute!
      t_policy = policy
      t_policy.aasm_state = "hbx_canceled"
      t_policy.enrollees.each do |en|
        unless en.coverage_ended?
          en.coverage_end = en.coverage_start
          en.coverage_status = 'inactive'
          en.employment_status_code = 'terminated'
        end
      end
      t_policy.save!
    end

    def transaction_id
      @transaction_id ||= TransactionIdGenerator.generate_bgn02_compatible_transaction_id
    end

    private

    def initialize_clone(other)
      @hbx_enrollment_id = other.hbx_enrollment_id.clone
      @affected_member_ids = other.affected_member_ids.clone
      @member_ids = other.member_ids.clone
      @terminate = other.terminate
    end
  end
end

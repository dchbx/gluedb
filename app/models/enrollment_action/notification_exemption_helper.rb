module EnrollmentAction
  module NotificationExemptionHelper

    # Determine if notification should be sent for a termination.
    #
    # @param policy [Policy] the policy in question, after termination
    # @param termination_date [Date] the scheduled termination date
    # @param check_npt_change [Boolean] check if the NPT flag has changed
    # @param old_npt_val [Boolean] the value of the NPT flag prior to the change
    # @return [Boolean]
    def termination_event_exempt_from_notification?(policy, termination_date, check_npt_change = false, old_npt_val = nil)
      return false if policy.is_shop?
      if check_npt_change
        return false if (old_npt_val != policy.term_for_np)
      end
      (termination_date.month == 12) && (termination_date.day == 31)
    end
  end
end
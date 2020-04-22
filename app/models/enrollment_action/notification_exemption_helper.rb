module EnrollmentAction
  module NotificationExemptionHelper
    def termination_event_exempt_from_notification?(policy, termination_date, check_npt_change = false, old_npt_val = nil)
      return false if policy.is_shop?
      if check_npt_change
        return false if (old_npt_val != policy.term_for_np)
      end
      (termination_date.month == 12) && (termination_date.day == 31)
    end
  end
end
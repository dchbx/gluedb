module EnrollmentAction
  class ReselectionOfExistingCoverage < Base
    extend PlanComparisonHelper
    extend DependentComparisonHelper
    def self.qualifies?(chunk)
      return false if chunk.length < 2
      return false unless same_plan?(chunk)
      return false if new_market?(chunk)
      !(dependents_dropped?(chunk) || dependents_added?(chunk))
    end

    def persist
      policy_to_change = termination.existing_policy
      policy_to_change.hbx_enrollment_ids << action.hbx_enrollment_id
      policy_to_change.save
    end

    def publish
      [true, {}]
    end
  end
end

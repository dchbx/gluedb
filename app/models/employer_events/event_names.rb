module EmployerEvents
  class EventNames
    
    EVENT_WHITELIST = %w(
address_changed
contact_changed
fein_corrected
name_changed
broker_added
broker_terminated
general_agent_added
general_agent_terminated
benefit_coverage_initial_application_eligible
benefit_coverage_renewal_application_eligible
benefit_coverage_renewal_carrier_dropped
benefit_coverage_period_terminated_voluntary
benefit_coverage_period_terminated_nonpayment
    )

    EXCLUDED_FOR_NOW = %w(
benefit_coverage_renewal_terminated_voluntary
benefit_coverage_period_terminated_relocated
benefit_coverage_renewal_terminated_ineligible
benefit_coverage_period_reinstated
    )

    FIRST_TIME_EMPLOYER_EVENT_NAME = "benefit_coverage_initial_application_eligible"
    RENEWAL_SUCCESSFUL_EVENT = "benefit_coverage_renewal_application_eligible"
    RENEWAL_CARRIER_CHANGE_EVENT = "benefit_coverage_renewal_carrier_dropped"
    TERMINATION_EVENT = %w(benefit_coverage_period_terminated_voluntary
                            benefit_coverage_period_terminated_nonpayment
    )
  end
end

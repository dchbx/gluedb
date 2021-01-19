require "multi_forkr"

Rails.application.eager_load!
MultiForkr.new({
  Listeners::EmployerEventReducerListener => 1,
  Listeners::EmployerUpdatedListener => 1,
  Listeners::EmployerDigestDropListener => 1,
  Listeners::PaymentProcessorTransactionListener => 1,
  Listeners::ReportEligibilityUpdatedReducerListener => 1,
  Listeners::ReportEligibilityUpdatedDigestDropListener => 1
}).run

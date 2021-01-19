require "rails_helper"

describe ExternalEvents::ExternalPolicyAssistanceChange, "given:
  - an existing policy
  - a policy CV with assistance amount updates
" do


  let(:policy_enrollment_individual_market) do
    instance_double(
      Openhbx::Cv2::PolicyEnrollmentIndividualMarket,
      applied_aptc_amount: aptc_amount_string
    )
  end

  let(:policy_enrollment) do
    instance_double(
      Openhbx::Cv2::PolicyEnrollment,
      total_responsible_amount: tot_res_amt_string,
      premium_total_amount: pre_amt_tot_string,
      individual_market: policy_enrollment_individual_market
    )
  end
  let(:policy) { instance_double(Policy) }
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment) }
  let(:effective_aptc_date) { double }
  let(:aptc_amount_string) { "23.21" }
  let(:aptc_amount) { BigDecimal.new(aptc_amount_string) }
  let(:pre_amt_tot_string) { "123.45" }
  let(:pre_amt_tot) { BigDecimal.new(pre_amt_tot_string) }
  let(:tot_res_amt_string) { "100.44" }
  let(:tot_res_amt) { BigDecimal.new(tot_res_amt_string) }

  let(:update_event) do
    instance_double(
      ExternalEvents::EnrollmentEventNotification,
      :policy_cv => policy_cv,
      :subscriber_start => effective_aptc_date
    )
  end

  subject { ExternalEvents::ExternalPolicyAssistanceChange.new(policy, update_event) }

  before :each do
    allow(policy).to receive(:save!).and_return(true)
    allow(policy).to receive(:set_aptc_effective_on).with(effective_aptc_date, aptc_amount, pre_amt_tot, tot_res_amt).and_return(true)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it "notifies of the assistance change" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "updates the aptc" do
    expect(policy).to receive(:set_aptc_effective_on).with(effective_aptc_date, aptc_amount, pre_amt_tot, tot_res_amt).and_return(true)
    subject.persist
  end
end

require "rails_helper"

describe ExternalEvents::ExternalPolicyReinstate, "given:
- a shop cv policy object
- an shop existing policy 
" do

  let(:plan_cv) { instance_double(Openhbx::Cv2::PlanLink) }
  let(:shop_market) { instance_double(Openhbx::Cv2::PolicyEnrollmentShopMarket, :total_employer_responsible_amount => tot_emp_res_amt, :cobra_eligibility_date => cobra_start_date_str) }
  let(:policy_enrollment) do
    instance_double(
      Openhbx::Cv2::PolicyEnrollment,
      :shop_market => shop_market,
      :total_responsible_amount => tot_res_amt,
      :premium_total_amount => pre_amt_tot
    )
  end
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => policy_enrollment, :enrollees => [enrollee_node], :id => policy_id) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee], :hbx_enrollment_ids => hbx_enrollment_ids_field_proxy) }
  let(:enrollee_node) { instance_double(Openhbx::Cv2::Enrollee, :member => member_node) }
  let(:member_node) { instance_double(Openhbx::Cv2::EnrolleeMember, :id => subscriber_id) }
  let(:pre_amt_tot) { "123.45" }
  let(:tot_res_amt) { "123.45" }
  let(:cobra_start_date) { Date.new(2017, 2, 1) }
  let(:cobra_start_date_str) { "20170201" }
  let(:tot_emp_res_amt) { "0.00" }
  let(:policy_id) { "a policy id" }
  let(:hbx_enrollment_ids_field_proxy) { double }
  let(:subscriber_id) { "subscriber id" }
  let(:enrollee) { instance_double(Enrollee, :m_id => subscriber_id) }

  subject { ExternalEvents::ExternalPolicyReinstate.new(policy_cv, policy) }

  let(:expected_policy_update_args) do
      {
        :aasm_state => "resubmitted", :term_for_np=>false
      }
  end

  let(:expected_enrollee_update_args) do
      {
        :aasm_state => "submitted"
      }
  end

  before :each do
    allow(policy).to receive(:update_attributes!) do |args|
      expect(args).to eq(expected_policy_update_args)
    end
    allow(enrollee).to receive(:ben_stat=).with("active")
    allow(enrollee).to receive(:emp_stat=).with("active")
    allow(enrollee).to receive(:coverage_end=).with(nil)
    allow(enrollee).to receive(:save!)
    allow(hbx_enrollment_ids_field_proxy).to receive(:<<).with(policy_id)
    allow(policy).to receive(:reload)
    allow(policy).to receive(:save!)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it "notifies of the update" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "updates the policy attributes" do
    expect(policy).to receive(:update_attributes!) do |args|
      expect(args).to eq(expected_policy_update_args)
    end
    subject.persist
  end

  it "sets the enrollment as active" do
    expect(enrollee).to receive(:ben_stat=).with("active")
    expect(enrollee).to receive(:emp_stat=).with("active")
    expect(enrollee).to receive(:coverage_end=).with(nil)
    expect(enrollee).to receive(:save!)
    subject.persist
  end

  it "updates the hbx_enrollment_ids list" do
    expect(hbx_enrollment_ids_field_proxy).to receive(:<<).with(policy_id)
    subject.persist
  end
end

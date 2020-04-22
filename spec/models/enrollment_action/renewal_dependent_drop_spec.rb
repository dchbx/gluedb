require 'rails_helper'

describe EnrollmentAction::RenewalDependentDrop, "given an enrollment event set that:
-- is not a termination
-- is not a passive renewal
-- has renewal candidates
-- dependents dropped" do
  let(:renewing_enrollment) { double(:active_member_ids => [1,2]) }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false,
                                  :all_member_ids => [1]
                                ) }

  subject { EnrollmentAction::RenewalDependentDrop }

  before do
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event).and_return([renewing_enrollment])
    allow(subject).to receive(:renewal_dependents_added?).with(renewing_enrollment, event).and_return(false)
    allow(subject).to receive(:renewal_dependents_dropped?).with(renewing_enrollment, event).and_return(true)
  end
  it "qualifies" do
    expect(subject.qualifies?([event])).to be_truthy
  end
end

describe EnrollmentAction::RenewalDependentDrop, "given a qualified enrollent set, being persisted" do
  let(:is_shop) { true }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }
  let(:old_policy) { instance_double(Policy, :active_member_ids => [1, 2], policy_end: member_end_date, :is_shop? => is_shop) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }

  let(:subscriber_start) { Date.today }
  let(:member_end_date) { Date.today - 1.day }
  let(:terminated_member_ids) { [2] }

  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1],
    :hbx_enrollment_id => 3,
    :subscriber_start => subscriber_start,
    :is_cobra? => false
    ) }

  subject do
    EnrollmentAction::RenewalDependentDrop.new(nil, action_event)
  end

  before :each do
    allow(EnrollmentAction::RenewalDependentDrop).to receive(:same_carrier_renewal_candidates).with(action_event).and_return([old_policy])

    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).and_return(primary_db_record)

    allow(EnrollmentAction::RenewalDependentDrop).to receive(:other_carrier_renewal_candidates).with(action_event).and_return([old_policy])
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(old_policy).to receive(:terminate_member_id_on).with(2, member_end_date).and_return(true)
    allow(subject.action).to receive(:kind).and_return(action_event)
    allow(Observers::PolicyUpdated).to receive(:notify).with(old_policy)
  end

  it "creates the new policy" do
    expect(subject.persist).to be_truthy
  end
  
  it "terminates the dropped member" do
    expect(old_policy).to receive(:terminate_member_id_on).with(2, member_end_date).and_return(true)
    subject.persist
  end

  it "assigns the termination information for the dropped dependent" do
    subject.persist
    expect(subject.terminated_policy_information).to eq [[old_policy, [2]]]
  end

  describe "given IVL with end date of not 12/31" do
    let(:is_shop) { false }
    let(:subscriber_start) { Date.new(2015, 6, 1) }
    let(:member_end_date) { Date.new(2015, 5, 31) }

    it "notifies of the termination" do
      expect(Observers::PolicyUpdated).to receive(:notify).with(old_policy)
      subject.persist
    end
  end

  describe "given IVL with end date of 12/31" do
    let(:is_shop) { false }

    let(:subscriber_start) { Date.new(2016, 1, 1) }
    let(:member_end_date) { Date.new(2015, 12, 31) }

    it "notifies of the termination" do
      expect(Observers::PolicyUpdated).not_to receive(:notify).with(old_policy)
      subject.persist
    end
  end
end

describe EnrollmentAction::RenewalDependentDrop, "given a qualified enrollent set, being published" do
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }
  let(:member_end_date) { Date.today - 1.day }
  let(:terminated_member_ids) { [2] }

  let(:subscriber_start) { Date.today }

  let(:amqp_connection) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:event_xml) { double }
  let(:action_helper_result_xml) { double }

  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1],
    :hbx_enrollment_id => 3,
    :employer_hbx_id => employer_hbx_id,
    :subscriber_start => subscriber_start
    ) }

  let(:action_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  let(:terminated_policy_eg_id) { 3 }
  let(:employer_hbx_id) { 1 }
  let(:employer) { instance_double(Employer, :hbx_id => employer_hbx_id) }
  let(:termination_writer) {
    instance_double(::EnrollmentAction::EnrollmentTerminationEventWriter)
  }
  let(:termination_helper_result_xml) { double }
  let(:termination_writer_result_xml) { double }
  let(:termination_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => termination_helper_result_xml
  ) }

  let(:terminated_policy) {
    instance_double(Policy, :eg_id => terminated_policy_eg_id, :employer => employer, :reload => true, active_member_ids: [1])
  }

  subject do
    EnrollmentAction::RenewalDependentDrop.new(nil, action_event)
  end

  before :each do
    subject.terminated_policy_information = [[terminated_policy,[2]]]
    allow(::EnrollmentAction::EnrollmentTerminationEventWriter).to receive(:new).with(terminated_policy, [1, 2]).and_return(termination_writer)
    allow(termination_writer).to receive(:write).with("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#change_member_terminate").and_return(termination_writer_result_xml)
    allow(EnrollmentAction::ActionPublishHelper).
      to receive(:new).
      with(event_xml).and_return(action_helper)
    allow(action_helper).
      to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew").
      and_return(true)
    allow(action_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 3, 1).and_return([true, nil])
    allow(::EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_writer_result_xml).and_return(termination_publish_helper)
    allow(termination_publish_helper).
      to receive(:filter_affected_members).with([2])
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, terminated_policy_eg_id, employer_hbx_id)
  end

  it "publishes successfully" do
    expect(subject.publish.first).to be_truthy
  end

  it "terminates the specified enrollments" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, terminated_policy_eg_id, employer_hbx_id)
    subject.publish
  end

  it "publishes the renewal enrollment" do
    expect(subject).
      to receive(:publish_edi).
      with(amqp_connection, action_helper_result_xml, 3, 1)
    subject.publish
  end
end

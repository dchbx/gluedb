require 'rails_helper'

describe EnrollmentAction::PassiveRenewal, "enrollment set for passive renewal event" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 2) }

  let(:event_1) {
    instance_double(ExternalEvents::EnrollmentEventNotification,
                    :existing_plan => plan,
                    :is_termination? => "urn:openhbx:terms:v1:enrollment#terminate_enrollment",
                    :all_member_ids => [1,2]) }
  let(:event_2) {
    instance_double(ExternalEvents::EnrollmentEventNotification,
                    :existing_plan => new_plan,
                    :is_termination? => false,
                    :is_passive_renewal? => "urn:openhbx:terms:v1:enrollment#auto_renew",
                    :all_member_ids => [1,2]) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::PassiveRenewal }

  it "does not qualify with termiantion event" do
    expect(subject.qualifies?([event_1])).to be_falsey
  end

  it "qualify with passive renewal" do
    expect(subject.qualifies?([event_2])).to be_truthy
  end

  it "does not qualifies with two events" do
    expect(subject.qualifies?(event_set)).to be_falsey
  end
end

describe EnrollmentAction::PassiveRenewal, "persists enrollment set for passive renewal event" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1, year: Date.today.year, coverage_type: "health") }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 1) }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1], market: "individual", plan: plan) }

  let(:passive_renewal_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => new_plan,
    :is_cobra? => false
    ) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }


  subject { EnrollmentAction::PassiveRenewal.new(nil, passive_renewal_event) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).
      and_return(primary_db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, new_plan, false, market_from_payload: subject.action).
      and_return(policy_updater)
    allow(::Listeners::PolicyUpdatedObserver).to receive(:broadcast).and_return(nil)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:kind).and_return(passive_renewal_event)
    allow(policy_updater).to receive(:created_policy).and_return(policy)
  end

  it "passive renewal persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::PassiveRenewal, "publish enrollment set for passive renewal event" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:passive_renewal_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1
    ) }

  subject { EnrollmentAction::PassiveRenewal.new(nil, passive_renewal_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew").and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, passive_renewal_event.hbx_enrollment_id, passive_renewal_event.employer_hbx_id)
  end

  it "publishes an event of type auto renew" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#auto_renew").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end

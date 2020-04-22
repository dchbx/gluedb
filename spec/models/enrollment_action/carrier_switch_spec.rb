require "rails_helper"

describe EnrollmentAction::CarrierSwitch, "Carrier switch" do

  let(:plan_1) { instance_double(Plan, :id => 1, :carrier_id => 1) }
  let(:plan_2) { instance_double(Plan, :id => 2, :carrier_id => 2) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2,3] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan_1, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan_2, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::CarrierSwitch }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::CarrierSwitch, "given a qualified enrollment set, being persisted" do
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:member_new) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:enrollee_secondary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_secondary) }
  let(:enrollee_new) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_new) }

  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary, enrollee_new]) }
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1,2], :terminate_as_of => subscriber_end, :policy_end => subscriber_end, :is_shop? => true) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:secondary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:new_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:subscriber_end) { Date.today - 1.day }

  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1,2,3],
    :hbx_enrollment_id => 3,
    :is_cobra? => false
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => terminated_policy_cv,
    :existing_policy => policy,
    :subscriber_end => subscriber_end,
    :all_member_ids => [1,2]
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }

  subject do
    EnrollmentAction::CarrierSwitch.new(termination_event, action_event)
  end

  before :each do
    allow(policy).to receive(:term_for_np).and_return(false)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).and_return(primary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_secondary).and_return(secondary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_new).and_return(new_db_record)

    allow(policy).to receive(:save!).and_return(true)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:kind).and_return(action_event)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end

  it "notifies of the policy change" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end
end

describe EnrollmentAction::CarrierSwitch, "given a qualified enrollment set for terminate, and a new enrollment, being published" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:termination_event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago) }

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1) }

  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :event_xml => termination_event_xml,
    :all_member_ids => [1,2],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }
  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :event_xml => event_xml,
    :all_member_ids => [1,2],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }

  let(:termination_helper_result_xml) { double }

  let(:termination_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => termination_helper_result_xml
  ) }

  let(:action_helper_result_xml) { double }

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  subject do
    EnrollmentAction::CarrierSwitch.new(termination_event, action_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_event_xml).and_return(termination_publish_helper)
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(termination_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_publish_helper).to receive(:set_policy_id).with(1)
    allow(termination_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, termination_event.existing_policy.eg_id, termination_event.employer_hbx_id).and_return([true, {}])
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(action_publish_helper).to receive(:set_policy_id).with(1)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, action_event.hbx_enrollment_id, action_event.employer_hbx_id)
    allow(termination_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
  end

  it "publishes an event of enrollment termination" do
    expect(termination_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id" do
    expect(termination_publish_helper).to receive(:set_policy_id).with(1).and_return(true)
    subject.publish
  end

  it "sets member start dates" do
    expect(termination_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    subject.publish
  end

  it "publishes termination resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, termination_event.existing_policy.eg_id, termination_event.employer_hbx_id)
    subject.publish
  end

  it "publishes an event of enrollment initialization" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
    subject.publish
  end

  it "clears all member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes initialization resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, action_event.hbx_enrollment_id, action_event.employer_hbx_id)
    subject.publish
  end

  it "corrects the qualifying event type on the termination" do
    expect(termination_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
    subject.publish
  end
end

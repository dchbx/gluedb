require 'rails_helper'

describe EnrollmentAction::CobraNewPolicySwitchover, "given:
- 1 event
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification) }

  subject { EnrollmentAction::CobraNewPolicySwitchover }

  it "does not qualify" do
    expect(subject.qualifies?([event_1])).to be_false
  end

end

describe EnrollmentAction::CobraNewPolicySwitchover, "given:
- an event that is a termination
- an event that is an initial, but not cobra
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: false) }

  subject { EnrollmentAction::CobraNewPolicySwitchover }

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end
end

describe EnrollmentAction::CobraNewPolicySwitchover, "given:
- an event that is a termination
- an event that is an initial, a cobra, and for a different carrier
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true, :existing_plan => plan_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: true, :existing_plan => plan_2) }
  let(:plan_1) { instance_double(Plan, carrier_id: 1) }
  let(:plan_2) { instance_double(Plan, carrier_id: 2) }

  subject { EnrollmentAction::CobraNewPolicySwitchover }

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end
end

describe EnrollmentAction::CobraNewPolicySwitchover, "given:
- an event that is a termination
- an event that is an initial, a cobra, for the same carrier, and does not have the start and end dates line up
- the carrier is not capable of reinstates
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true, :existing_plan => plan_1, :policy_cv => policy_cv1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: true, :existing_plan => plan_2, :policy_cv => policy_cv2) }
  let(:plan_1) { instance_double(Plan, carrier_id: 1) }
  let(:plan_2) { instance_double(Plan, carrier_id: 1) }
  let(:policy_cv1) { instance_double(Openhbx::Cv2::Policy) }
  let(:policy_cv2) { instance_double(Openhbx::Cv2::Policy) }
  let(:start_subscriber) { double }
  let(:term_subscriber) { double }
  let(:term_date) { Date.today }
  let(:start_date) { term_date + 2.days }

  subject { EnrollmentAction::CobraNewPolicySwitchover }

  before :each do
    allow(subject).to receive(:extract_subscriber).with(policy_cv1).and_return(term_subscriber)
    allow(subject).to receive(:extract_subscriber).with(policy_cv2).and_return(start_subscriber)
    allow(subject).to receive(:extract_enrollee_end).with(term_subscriber).and_return(term_date)
    allow(subject).to receive(:extract_enrollee_start).with(start_subscriber).and_return(start_date)
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_2).and_return(false)
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end
end

describe EnrollmentAction::CobraNewPolicySwitchover, "given:
- an event that is a termination
- an event that is an initial, a cobra, for the same carrier, and has the start and end dates line up
- the carrier is not capable of reinstates
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true, :existing_plan => plan_1, :policy_cv => policy_cv1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: true, :existing_plan => plan_2, :policy_cv => policy_cv2) }
  let(:plan_1) { instance_double(Plan, carrier_id: 1) }
  let(:plan_2) { instance_double(Plan, carrier_id: 1) }
  let(:policy_cv1) { instance_double(Openhbx::Cv2::Policy) }
  let(:policy_cv2) { instance_double(Openhbx::Cv2::Policy) }
  let(:start_subscriber) { double }
  let(:term_subscriber) { double }
  let(:term_date) { Date.today }
  let(:start_date) { term_date + 1.days }

  subject { EnrollmentAction::CobraNewPolicySwitchover }

  before :each do
    allow(subject).to receive(:extract_subscriber).with(policy_cv1).and_return(term_subscriber)
    allow(subject).to receive(:extract_subscriber).with(policy_cv2).and_return(start_subscriber)
    allow(subject).to receive(:extract_enrollee_end).with(term_subscriber).and_return(term_date)
    allow(subject).to receive(:extract_enrollee_start).with(start_subscriber).and_return(start_date)
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_2).and_return(false)
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_true
  end
end

describe EnrollmentAction::CobraNewPolicySwitchover, "given an enrollment event set that indicates a cobra switchover" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 1) }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1]) }

  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => new_plan,
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :subscriber_end => termination_date
    ) }
  let(:termination_date) { DateTime.new(2017,2,28) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }


  subject { EnrollmentAction::CobraNewPolicySwitchover.new(termination_event, plan_change_event) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).
      and_return(primary_db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, new_plan, true, market_from_payload: subject.action).
      and_return(policy_updater)
    allow(policy).to receive(:terminate_as_of).with(termination_date).
      and_return(true)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:kind).and_return(plan_change_event)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists the change" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::CobraNewPolicySwitchover, "given a qualified enrollment set for terminate, and a new cobra enrollment, being published" do
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
    EnrollmentAction::CobraNewPolicySwitchover.new(termination_event, action_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_event_xml).and_return(termination_publish_helper)
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(termination_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_publish_helper).to receive(:set_policy_id).with(1)
    allow(termination_publish_helper).to receive(:set_member_starts).with({ 1 => :one_month_ago, 2 => :one_month_ago })
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, termination_event.existing_policy.eg_id, termination_event.employer_hbx_id).and_return([true, {}])
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
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
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
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

end

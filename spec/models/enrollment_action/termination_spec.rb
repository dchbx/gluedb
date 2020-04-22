require "rails_helper"

describe EnrollmentAction::Termination, "given an EnrollmentAction array that:
  - has one element that is a termination
  - has one element that is not a termination
  - has more than one element 
  - the enrollment is for a carrier who is reinstate capable" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false) }

  subject { EnrollmentAction::Termination }

  before :each do
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(true)
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_2).and_return(true)
  end

  it "qualifies" do
    expect(subject.qualifies?([event_1])).to be_truthy
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_2])).to be_false
  end

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end

  context "
  - has one element that is a termination
  - the enrollment is for a carrier who is not reinstate capable
  " do

    it "does not qualify" do
      allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(false)
      expect(subject.qualifies?([event_1])).to be_false
    end
  end
end

describe EnrollmentAction::Termination, "given a valid shop enrollment" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: (Date.today - 1.day), is_shop?: true) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(false)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given a valid IVL enrollment, ending 12/31" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: ((Date.today - 1.day)), is_shop?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(false)
    allow(policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.new(Date.today.year, 12, 31))
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "does not notify of the termination" do
    expect(Observers::PolicyUpdated).not_to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given a valid IVL enrollment, ending 12/31, but with an npt change" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], policy_end: ((Date.today - 1.day)), is_shop?: false) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(policy).to receive(:term_for_np).and_return(true, false)
    allow(policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.new(Date.today.year, 12, 31))
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::Termination, "given a valid enrollment" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: :one_month_ago) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee], eg_id: 1) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: event_xml,
    existing_policy: policy,
    all_member_ids: [enrollee.m_id],
    event_responder: event_responder,
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    to_xml: action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(action_publish_helper).to receive(:set_policy_id).with(policy.id)
    allow(action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
  end

  subject do
    EnrollmentAction::Termination.new(termination_event, nil)
  end

  it "publishes a termination event" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id" do
    expect(action_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "sets member start" do
    expect(action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end
end

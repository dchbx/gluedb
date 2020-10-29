require 'rails_helper'

describe EnrollmentAction::InitialEnrollment, "given:
- a single event
- that begins enrollment" do

  let(:enrollment_event) { instance_double(::ExternalEvents::EnrollmentEventNotification, :is_termination? => false, :is_passive_renewal? => false) }

  before :each do
    allow(EnrollmentAction::InitialEnrollment).to receive(:any_renewal_candidates?).with(enrollment_event).and_return(false)
  end

  it "qualifies as the correct enrollment action" do
    expect(EnrollmentAction::InitialEnrollment.qualifies?([enrollment_event])).to be_truthy
  end
end

describe EnrollmentAction::InitialEnrollment, "with an initial enrollment event, being persisted" do
  let(:member_from_xml) { instance_double(Openhbx::Cv2::EnrolleeMember) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_from_xml) }
  let(:enrollees) { [enrollee] }
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy,:enrollees => enrollees) }
  let(:enrollment_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => policy_cv,
    :existing_plan => existing_plan,
    :is_cobra? => false,
    :kind => "coverall"
  ) }

  let(:existing_plan) { double }
  let(:member_database_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:policy_database_record) { instance_double(ExternalEvents::ExternalPolicy, :persist => true) }

  subject do
    EnrollmentAction::InitialEnrollment.new(nil, enrollment_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_from_xml).and_return(member_database_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(policy_cv, existing_plan, false, market_from_payload: subject.action.kind).and_return(policy_database_record)
    allow(subject.action).to receive(:existing_policy).and_return(false)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end

end

describe EnrollmentAction::InitialEnrollment, "with an initial enrollment event, being published" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:carrier) { instance_double(Carrier, :retro_renewal_transmitted_as_renewal => true) }
  let(:policy) { instance_double(Policy, carrier: carrier) }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollment_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :existing_policy => policy,
    :hbx_enrollment_id => hbx_enrollment_id,
    :employer_hbx_id => employer_hbx_id
  ) }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  let(:action_helper_result_xml) { double }
  let(:hbx_enrollment_id) { double }
  let(:employer_hbx_id) { double }

  subject do
    EnrollmentAction::InitialEnrollment.new(nil, enrollment_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, hbx_enrollment_id, employer_hbx_id)
    allow(enrollment_event).to receive(:is_retro_renewal_policy?).and_return(false)
  end

  it "publishes an event of type initial enrollment" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
    subject.publish
  end

  it "clears all member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes the resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, hbx_enrollment_id, employer_hbx_id)
    subject.publish
  end

  it "publishes an event of type auto renew enrollment" do
    allow(enrollment_event).to receive(:is_retro_renewal_policy?).and_return(true)
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
    subject.publish
  end
end

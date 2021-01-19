require 'rails_helper'

describe EnrollmentAction::CobraNewPolicyReinstate, "given:
- 2 events
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification) }

  subject { EnrollmentAction::CobraNewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end

end

describe EnrollmentAction::CobraNewPolicyReinstate, "given:
- has one enrollment
- that enrollment is a termination
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }

  subject { EnrollmentAction::CobraNewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1])).to be_false
  end
end

describe EnrollmentAction::CobraNewPolicyReinstate, "given:
- has one enrollment
- that enrollment is not a termination
- that enrollment is not cobra
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: false) }

  subject { EnrollmentAction::CobraNewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1])).to be_false
  end
end

describe EnrollmentAction::CobraNewPolicyReinstate, "given:
- has one enrollment
- that enrollment is not a termination
- that enrollment is cobra
- there is an already terminated corresponding shop policy
- the enrollment is for a carrier who is not reinstate capable
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: true) }

  subject { EnrollmentAction::CobraNewPolicyReinstate }

  before :each do
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(false)
    allow(subject).to receive(:same_carrier_reinstatement_candidates).with(event_1).and_return([double])
  end

  it "qualifies" do
    expect(subject.qualifies?([event_1])).to be_true
  end
end

describe EnrollmentAction::CobraNewPolicyReinstate, "with an cobra reinstate enrollment event, being persisted" do
  let(:member_from_xml) { instance_double(Openhbx::Cv2::EnrolleeMember) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_from_xml) }
  let(:enrollees) { [enrollee] }
  let(:policy_cv) { instance_double(Openhbx::Cv2::Policy,:enrollees => enrollees) }
  let(:enrollment_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => policy_cv,
    :existing_plan => existing_plan
  ) }

  let(:existing_plan) { double }
  let(:member_database_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:policy_database_record) { instance_double(ExternalEvents::ExternalPolicy, :persist => true) }
  let(:cobra_reinstate) { true }

  subject do
    EnrollmentAction::CobraNewPolicyReinstate.new(nil, enrollment_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_from_xml).and_return(member_database_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(policy_cv, existing_plan,cobra_reinstate, market_from_payload: subject.action).and_return(policy_database_record)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:kind).and_return(enrollment_event)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::CobraNewPolicyReinstate, "with an cobra reinstate enrollment event, being published" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollment_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
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
    EnrollmentAction::CobraNewPolicyReinstate.new(nil, enrollment_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
    allow(action_publish_helper).to receive(:set_market_type).with("urn:openhbx:terms:v1:aca_marketplace#cobra")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, hbx_enrollment_id, employer_hbx_id)
  end

  it "publishes an event of type reenroll enrollment" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
    subject.publish
  end

  it "publishes set market type cobra" do
    expect(action_publish_helper).to receive(:set_market_type).with("urn:openhbx:terms:v1:aca_marketplace#cobra")
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
end

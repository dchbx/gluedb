require 'rails_helper'

describe EnrollmentAction::NewPolicyReinstate, "given:
- 2 events
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification) } 
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification) }

  subject { EnrollmentAction::NewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1, event_2])).to be_false
  end

end

describe EnrollmentAction::NewPolicyReinstate, "given:
- has one enrollment
- that enrollment is a termination
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }

  subject { EnrollmentAction::NewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1])).to be_false
  end
end

describe EnrollmentAction::NewPolicyReinstate, "given:
- has one enrollment
- that enrollment is not a termination
- that enrollment is cobra
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: true) }

  subject { EnrollmentAction::NewPolicyReinstate }

  it "does not qualify" do
    expect(subject.qualifies?([event_1])).to be_false
  end
end

describe EnrollmentAction::NewPolicyReinstate, "given:
- has one enrollment
- that enrollment is not a termination
- that enrollment is not cobra
- there is an already terminated corresponding policy
- the enrollment has continuation of coverage
- the enrollment is for a carrier who is not reinstate capable
" do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false, is_cobra?: false) }

  subject { EnrollmentAction::NewPolicyReinstate }

  before :each do
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(false)
    allow(subject).to receive(:is_continuation_of_coverage_event?).with(event_1).and_return(true)
    allow(subject).to receive(:any_market_reinstatement_candidates).with(event_1).and_return([double])
  end

  it "qualifies" do
    expect(subject.qualifies?([event_1])).to be_true
  end
end

describe EnrollmentAction::NewPolicyReinstate, "with a reinstate enrollment event, being persisted" do
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

  subject do
    EnrollmentAction::NewPolicyReinstate.new(nil, enrollment_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_from_xml).and_return(member_database_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(policy_cv, existing_plan, false, policy_reinstate: true).and_return(policy_database_record)
    allow(subject.action).to receive(:existing_policy).and_return(false)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::NewPolicyReinstate, "with an cobra reinstate enrollment event, being published" do
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
    EnrollmentAction::NewPolicyReinstate.new(nil, enrollment_event)
  end

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, hbx_enrollment_id, employer_hbx_id)
  end

  it "publishes an event of type reenroll enrollment" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#reinstate_enrollment")
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

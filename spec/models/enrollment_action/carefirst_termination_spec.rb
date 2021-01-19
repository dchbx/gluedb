require "rails_helper"

describe EnrollmentAction::CarefirstTermination, "given an EnrollmentAction array that:
  - has one element that is a termination
  - has one element that is not a termination
  - has more than one element
  - the enrollment is for a carrier who is not reinstate capable", :dbclean => :after_each do

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false) }

  subject { EnrollmentAction::CarefirstTermination }

  before :each do
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_1).and_return(false)
    allow(subject).to receive(:reinstate_capable_carrier?).with(event_2).and_return(false)
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
end

describe EnrollmentAction::CarefirstTermination, "given a valid terminated enrollment", :dbclean => :after_each do

  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:carrier) { instance_double(Carrier, :termination_cancels_renewal => false) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1], carrier: carrier, is_shop?: true) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    is_cancel?: false,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  before :each do
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
  end

  subject do
    EnrollmentAction::CarefirstTermination.new(termination_event, nil)
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::CarefirstTermination, "given a valid canceled enrollment", :dbclean => :after_each do
  let(:plan_link) { instance_double(Openhbx::Cv2::PlanLink, :id => 1, :active_year => "2019", :carrier => carrier_link) }
  let(:carrier_link) { instance_double(Openhbx::Cv2::CarrierLink, :id => 1) }
  let(:individual_enrollment_element) { instance_double(Openhbx::Cv2::PolicyEnrollmentIndividualMarket) }
  let(:enrollment_element) { instance_double(Openhbx::Cv2::PolicyEnrollment, :individual_market => individual_enrollment_element, :shop_market => nil, :plan => plan_link) }
  let(:canceled_policy_cv) { instance_double(Openhbx::Cv2::Policy, :policy_enrollment => enrollment_element,  enrollees: [enrollee], ) }
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    is_cancel?: true,
    policy_cv: canceled_policy_cv,
    existing_policy: policy,
    all_member_ids: [1,2]
    ) }

  let(:person) {FactoryGirl.create(:person)}
  let(:member) {person.members.first}
  let!(:policy) { Policy.new(eg_id: '1', enrollees: [enrollee1], plan: plan, carrier: carrier ) }
  let!(:policy2) { Policy.new(eg_id: '2', enrollees: [enrollee2], plan: plan, carrier: carrier, employer_id: nil, aasm_state: "terminated", term_for_np: true ) }
  let!(:plan) { build(:plan) }
  let!(:carrier) {create(:carrier, termination_cancels_renewal: false)}
  let!(:enrollee1) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'active',
      relationship_status_code: 'self',
      coverage_start: Date.new(2019,4,1))
  end
  let!(:enrollee2) do
    Enrollee.new(
      m_id: member.hbx_member_id,
      benefit_status_code: 'active',
      employment_status_code: 'terminated',
      relationship_status_code: 'self',
      coverage_start: Date.new(2019,1,1),
      coverage_end: Date.new(2019,3,31))
  end

  before :each do
    person.update_attributes!(:authority_member_id => person.members.first.hbx_member_id)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    policy.save!
    policy2.save!
    policy2.update_attributes!(term_for_np: false)
  end

  subject do
    EnrollmentAction::CarefirstTermination.new(termination_event, nil)
  end

  it "persists" do
    expect(policy2.term_for_np).to eq false
    expect(subject.persist).to be_truthy
    policy2.reload
    expect(policy2.term_for_np).to eq true
  end
end

describe EnrollmentAction::CarefirstTermination, "given a valid enrollment", :dbclean => :after_each do
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
    EnrollmentAction::CarefirstTermination.new(termination_event, nil)
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

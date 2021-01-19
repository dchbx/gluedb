require "rails_helper"

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given an EnrollmentAction array that:
  - has one element that is a termination and concurrent policy
  - has one element that is a termination and not a concurrent policy
  - has more than one element" do

  let(:subscriber) { Enrollee.new(:m_id=> '1', :coverage_end => nil, :coverage_start => (Date.today - 2.month).beginning_of_month, :rel_code => "self") }
  let(:enrollee) { Enrollee.new(:m_id => "2", :coverage_end => nil, :coverage_start => (Date.today - 1.month).beginning_of_month, :relationship_status_code => "child") }
  let(:policy) { create(:policy, enrollees: [ subscriber, enrollee ]) }
  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: true, is_cancel?: true, existing_policy: policy, subscriber_start: (Date.today - 1.month).beginning_of_month, subscriber_end: (Date.today - 1.month).beginning_of_month, all_member_ids: [1, 2]) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, is_termination?: false) }

  subject { EnrollmentAction::ConcurrentPolicyCancelAndTerm }

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

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, member: member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [enrollee])}
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1]) }
  let(:termination_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      policy_cv: terminated_policy_cv,
      existing_policy: policy,
      all_member_ids: [1,2]
  ) }

  before :each do
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(Date.today)
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end

  it "persists" do
    expect(subject.persist).to be_truthy
  end

  context "when policy not found" do

    let!(:new_termination_event) { instance_double(
        ::ExternalEvents::EnrollmentEventNotification,
        policy_cv: terminated_policy_cv,
        existing_policy: nil,
        all_member_ids: [1,2]
    ) }

    subject do
      EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(new_termination_event, nil)
    end

    it "return false" do
      expect(subject.persist).to be_false
    end

  end
end

describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment, with concurrent termination" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: 1.month.ago.beginning_of_month, coverage_end: 1.month.since.end_of_month) }
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

  let(:termination_action_publish_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(termination_action_publish_helper)
    allow(termination_action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_action_publish_helper).to receive(:set_policy_id).with(policy.id)
    allow(termination_action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    allow(termination_action_publish_helper).to receive(:set_member_end_date).with({1 => enrollee.coverage_end})
    allow(termination_action_publish_helper).to receive(:filter_affected_members).with([enrollee.m_id])
    allow(termination_action_publish_helper).to receive(:filter_enrollee_members).with([enrollee.m_id])
    allow(termination_action_publish_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end

  it "publishes a termination event" do
    expect(termination_action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id" do
    expect(termination_action_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "sets member start" do
    expect(termination_action_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start})
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end
end


describe EnrollmentAction::ConcurrentPolicyCancelAndTerm, "given a valid enrollment, with concurrent cancel and termination" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: (Date.today - 1.month).beginning_of_month, coverage_end: Date.today.beginning_of_month) }
  let(:enrollee2) { double(m_id: 2, coverage_start: Date.today.beginning_of_month, coverage_end: Date.today.beginning_of_month) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee, enrollee2], eg_id: 1) }
  let(:termination_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      event_xml: event_xml,
      existing_policy: policy,
      all_member_ids: [enrollee.m_id, enrollee2.m_id],
      event_responder: event_responder,
      hbx_enrollment_id: 1,
      employer_hbx_id: 1
  ) }



  let(:cancel_action_helper_result_xml) { double }
  let(:termination_action_helper_result_xml) { double }

  let(:cancel_publish_action_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: cancel_action_helper_result_xml
  ) }

  let(:termination_publish_action_helper) { instance_double(
      EnrollmentAction::ActionPublishHelper,
      to_xml: termination_action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(cancel_publish_action_helper, termination_publish_action_helper)

    allow(cancel_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    allow(cancel_publish_action_helper).to receive(:set_policy_id).with(policy.id)
    allow(cancel_publish_action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => enrollee2.coverage_start})
    allow(cancel_publish_action_helper).to receive(:filter_affected_members).with([enrollee2.m_id])
    allow(cancel_publish_action_helper).to receive(:keep_member_ends).with([enrollee2.m_id])
    allow(cancel_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee2.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, cancel_action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id).and_return([true, {}])


    allow(termination_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    allow(termination_publish_action_helper).to receive(:set_policy_id).with(policy.id)
    allow(termination_publish_action_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => enrollee2.coverage_start})
    allow(termination_publish_action_helper).to receive(:set_member_end_date).with({1 => enrollee.coverage_end, 2 => enrollee2.coverage_end})
    allow(termination_publish_action_helper).to receive(:filter_affected_members).with([enrollee.m_id])
    allow(termination_publish_action_helper).to receive(:filter_enrollee_members).with([enrollee.m_id])
    allow(termination_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([enrollee.m_id])
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_action_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id).and_return([true, {}])
  end

  subject do
    EnrollmentAction::ConcurrentPolicyCancelAndTerm.new(termination_event, nil)
  end


  it "sets event for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    subject.publish
  end

  it "sets event for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    subject.publish
  end

  it "sets policy id for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_policy_id).with(1).and_return(true)
    subject.publish
  end

  it "sets policy id for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_policy_id).with(1).and_return(true)
    subject.publish
  end

  it "sets member start dates for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:set_member_starts).with({1 => (Date.today - 1.month).beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end

  it "sets member start dates for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_member_starts).with({1 => (Date.today - 1.month).beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end

  it "filter members for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:filter_affected_members).with([2])
    subject.publish
  end

  it "filter members for termination action helper" do
    expect(termination_publish_action_helper).to receive(:filter_affected_members).with([1])
    subject.publish
  end

  it "clears all member end dates before publishing for cancel action helper " do
    expect(cancel_publish_action_helper).to receive(:keep_member_ends).with([2])
    subject.publish
  end

  it "sets member end dates for termination action helper" do
    expect(termination_publish_action_helper).to receive(:set_member_end_date).with({1 => Date.today.beginning_of_month, 2 =>  Date.today.beginning_of_month})
    subject.publish
  end


  it "recalculate premium for cancel action helper" do
    expect(cancel_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([2])
    subject.publish
  end

  it "recalculate premium for termination action helper" do
    expect(termination_publish_action_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([1])
    subject.publish
  end

  it "publishes termination & reinstatment resulting xml to edi" do
    expect(subject).to receive(:publish_edi).exactly(2).times
    subject.publish
  end
end

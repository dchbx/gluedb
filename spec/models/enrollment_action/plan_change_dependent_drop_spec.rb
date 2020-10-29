require 'rails_helper'

describe EnrollmentAction::PlanChangeDependentDrop, "given an EnrollmentAction array that:
  - has less than two elements
  - is the same plan
  - doesn't have the same carrier
  - has no dropped dependents
  - is not the same plan, has the same carrier, and has dropped dependents" do

  let(:plan_1) { instance_double(Plan, id: 1, carrier_id: 1) }
  let(:plan_2) { instance_double(Plan, id: 2, carrier_id: 2) }
  let(:plan_3) { instance_double(Plan, id: 3, carrier_id: 1) }
  let(:main_event) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_1, all_member_ids: [1, 2, 3]) }
  let(:fails_plan_id_is_the_same) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_1, all_member_ids: [1, 2]) }
  let(:fails_carrier_ids_are_different) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_2, all_member_ids: [1, 2]) }
  let(:fails_no_dropped_dependents) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_2, all_member_ids: [1, 2, 3]) }
  let(:succeeds) { instance_double(ExternalEvents::EnrollmentEventNotification, existing_plan: plan_3, all_member_ids: [1, 2]) }

  subject { EnrollmentAction::PlanChangeDependentDrop }

  it "does not qualify because it has less than two elements" do
    expect(subject.qualifies?([main_event])).to be_false
  end

  it "does not qualify because both elements are the same plan" do
    expect(subject.qualifies?([main_event, fails_plan_id_is_the_same])).to be_false
  end

  it "does not qualify because the carrier IDs are different" do
    expect(subject.qualifies?([main_event, fails_carrier_ids_are_different])).to be_false
  end

  it "does not qualify because there are no dropped dependents" do
    expect(subject.qualifies?([main_event, fails_no_dropped_dependents])).to be_false
  end

  it "qualifies" do
    expect(subject.qualifies?([main_event, succeeds])).to be_truthy
  end
end

describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment set" do
  let(:primary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:dropped_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_member, dropped_member])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_member]) }
  let(:plan) { instance_double(Plan, id: 1) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1, 2]) }

  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1, 2]
  ) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberDrop) }

  subject { EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event) }

  context "with dropped dependents" do
    let(:dependent_drop_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      policy_cv: new_policy_cv,
      existing_plan: plan,
      all_member_ids: [1],
      hbx_enrollment_id: 1
    ) }
    it "returns an array containing the dropped dependents" do
      expect(subject.dropped_dependents).to eq([2])
    end
  end

  context "with no dropped dependents" do
    let(:dependent_drop_event) { instance_double(
      ::ExternalEvents::EnrollmentEventNotification,
      policy_cv: new_policy_cv,
      existing_plan: plan,
      all_member_ids: [1, 2],
      hbx_enrollment_id: 1
    ) }

    it "returns an empty array" do
      expect(subject.dropped_dependents).to eq([])
    end
  end
end


describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment set" do
  let(:primary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:secondary_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:dropped_member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:primary_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:carrier) { instance_double(Carrier, :plan_change_renewal_dependent_drop_transmitted_as_renewal => true) }
  let(:secondary_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:dropped_enrollee) { instance_double(Openhbx::Cv2::Enrollee, member: primary_member) }
  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_enrollee, secondary_enrollee, dropped_enrollee])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, enrollees: [primary_enrollee, secondary_enrollee]) }
  let(:plan) { instance_double(Plan, id: 1, carrier: carrier) }
  let(:policy) { instance_double(Policy, hbx_enrollment_ids: [1, 2, 3], carrier: carrier) }
  let(:db_record) { instance_double(ExternalEvents::ExternalMember, persist: true) }
  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: new_policy_cv,
    existing_plan: plan,
    all_member_ids: [1, 2],
    hbx_enrollment_id: 3,
    :is_cobra? => false
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    policy_cv: terminated_policy_cv,
    existing_policy: policy,
    all_member_ids: [1, 2, 3]
  ) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberDrop) }
  let(:expected_termination_date) { double }
  let(:active_policy) { instance_double(Policy) }

  subject { EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(primary_member).and_return(db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(secondary_member).and_return(db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(dropped_member).and_return(db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject).to receive(:select_termination_date).and_return(expected_termination_date)
    allow(subject.action).to receive(:kind).and_return(dependent_drop_event)
    allow(subject.action).to receive(:existing_plan).and_return(plan)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(dependent_drop_event).and_return([active_policy])
    allow(dependent_drop_event).to receive(:plan_change_dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(false)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "persists when all members persist" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::PlanChangeDependentDrop, "given a valid enrollment" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:termination_event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, connection: amqp_connection) }
  let(:enrollee) { double(m_id: 1, coverage_start: :one_month_ago) }
  let(:new_enrollee) { double(m_id: 2, coverage_start: :one_month_ago) }
  let(:dropped_enrollee) { double(m_id: 3, coverage_start: :one_month_ago) }
  let(:plan) { instance_double(Plan, id: 1) }
  let(:policy) { instance_double(Policy, id: 1, enrollees: [enrollee, new_enrollee, dropped_enrollee], eg_id: 1) }
  let(:dependent_drop_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: event_xml,
    all_member_ids: [1, 2],
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    event_xml: termination_event_xml,
    existing_policy: policy,
    all_member_ids: [1, 2, 3],
    event_responder: event_responder,
    hbx_enrollment_id: 1,
    employer_hbx_id: 1
  ) }
  let(:action_helper_result_xml) { double }
  let(:action_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    to_xml: action_helper_result_xml
  ) }
  let(:termination_helper_result_xml) { double }
  let(:termination_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    to_xml: termination_helper_result_xml
  ) }
  let(:expected_end_date) { double }

  subject { EnrollmentAction::PlanChangeDependentDrop.new(termination_event, dependent_drop_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_event_xml).and_return(termination_publish_helper)
    allow(termination_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    allow(termination_publish_helper).to receive(:set_policy_id).with(policy.id)
    allow(termination_publish_helper).to receive(:filter_affected_members).with([3]).and_return(true)
    allow(termination_publish_helper).to receive(:keep_member_ends).with([3])
    allow(termination_publish_helper).to receive(:set_member_ends).with(expected_end_date)
    allow(termination_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => new_enrollee.coverage_start, 3 => dropped_enrollee.coverage_start})
    allow(termination_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
    allow(termination_publish_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([1,2])
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id).and_return(true, [])
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_helper)
    allow(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product")
    allow(action_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_drop_event.hbx_enrollment_id, dependent_drop_event.employer_hbx_id)
    allow(subject).to receive(:select_termination_date).and_return(expected_end_date)
  end

  it "sets the action on the new enrollment" do
    expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product")
    subject.publish
  end

  it "sets the action on the old enrollment" do
    expect(termination_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_member_terminate")
    subject.publish
  end

  it "sets the policy id of the old enrollment" do
    expect(termination_publish_helper).to receive(:set_policy_id).with(1)
    subject.publish
  end

  it "sets the member starts of the old enrollment receives set_member_starts" do
    expect(termination_publish_helper).to receive(:set_member_starts).with({1 => enrollee.coverage_start, 2 => new_enrollee.coverage_start, 3 => dropped_enrollee.coverage_start})
    subject.publish
  end

  it "sets the affected members on the old enrollment" do
    expect(termination_publish_helper).to receive(:filter_affected_members).with([3])
    subject.publish
  end

  it "keeps member end dates on the old enrollment only for the terminated member" do
    expect(termination_publish_helper).to receive(:keep_member_ends).with([3])
    subject.publish
  end

  it "puts the correct qualifying event on the old enrollment" do
    expect(termination_publish_helper).to receive(:swap_qualifying_event).with(event_xml)
    subject.publish
  end

  it "updates the premium total to only include the remaining members" do
    expect(termination_publish_helper).to receive(:recalculate_premium_totals_excluding_dropped_dependents).with([1,2])
    subject.publish
  end

  it "publishes termination event xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, termination_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    subject.publish
  end

  it "publishes change_product event xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_drop_event.hbx_enrollment_id, dependent_drop_event.employer_hbx_id)
    subject.publish
  end

  it "publishes an auto renew event for drop dependents on renewal policy " do
    subject.plan_change_dep_drop_from_renewal = true
    expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
    subject.publish
  end
end

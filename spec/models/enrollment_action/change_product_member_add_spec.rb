require "rails_helper"

describe EnrollmentAction::PlanChangeDependentAdd, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a cancel for plan A
- the second enrollment is a start for plan A
- the second enrollment has more members
- the second enrollment has a different product" do

  let(:old_plan) { instance_double(Plan, :id => 1, :carrier_id => "1234") }
  let(:new_plan) { instance_double(Plan, :id => 2, :carrier_id => "1234") }
  let(:new_plan_different_carrier) { instance_double(Plan, :id => 3, :carrier_id => "4567") }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2,3] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => old_plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan, :all_member_ids => member_ids_2) }
  let(:event_3) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan_different_carrier, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }
  let(:event_set_different_carrier) { [event_1, event_3] }

  subject { EnrollmentAction::PlanChangeDependentAdd }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end

  it "does not qualify because of different carriers" do
    expect(subject.qualifies?(event_set_different_carrier)).to be_falsey
  end

  it "does not qualify because chunk contains only one event" do
    expect(subject.qualifies?(event_set.take(1))).to be_falsey
  end

end

describe EnrollmentAction::PlanChangeDependentAdd, "given a qualified enrollment set, being persisted" do
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:member_new) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 3) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:enrollee_secondary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_secondary) }
  let(:enrollee_new) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_new) }

  let(:terminated_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary])}
  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary, enrollee_new]) }
  let(:plan) { instance_double(Plan, :id => 1, carrier: carrier) }
  let(:carrier) { instance_double(Carrier, :plan_change_renewal_dependent_add_transmitted_as_renewal => true) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1,2], carrier: carrier) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:secondary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:new_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:dependent_add_event) { instance_double(
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
    :all_member_ids => [1,2]
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }
  let(:expected_termination_date) { double }
  let(:active_policy) { instance_double(Policy) }

  subject do
    EnrollmentAction::PlanChangeDependentAdd.new(termination_event, dependent_add_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).and_return(primary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_secondary).and_return(secondary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_new).and_return(new_db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(termination_event.existing_policy).to receive(:terminate_as_of).with(expected_termination_date).and_return(true)
    allow(termination_event).to receive(:subscriber_end).and_return(false)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:existing_plan).and_return(plan)
    allow(subject.action).to receive(:kind).and_return(dependent_add_event)
    allow(subject).to receive(:select_termination_date).and_return(expected_termination_date)
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(dependent_add_event).and_return([active_policy])
    allow(dependent_add_event).to receive(:plan_change_dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(false)
  end

  it "notifies of the termination" do
    expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
    subject.persist
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end

  it "terminates with the correct end date" do
    expect(subject).to receive(:select_termination_date).and_return(expected_termination_date)
    subject.persist
  end
end


describe EnrollmentAction::PlanChangeDependentAdd, "given a qualified enrollment set, being published" do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago) }

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:carrier) { instance_double(Carrier, :plan_change_renewal_dependent_add_transmitted_as_renewal => true) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1, :carrier => carrier) }
  let(:active_policy) { instance_double(Policy) }
  let(:dependent_add_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_xml => event_xml,
    :existing_policy => policy,
    :all_member_ids => [1,2],
    :hbx_enrollment_id => 2,
    :employer_hbx_id => 1
  ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :all_member_ids => [1],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }
  let(:action_helper_result_xml) { double }

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:filter_affected_members).with([2]).and_return(true)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product_member_add")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_add_event.hbx_enrollment_id, termination_event.employer_hbx_id)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(dependent_add_event).and_return([active_policy])
    allow(dependent_add_event).to receive(:plan_change_dep_add_or_drop_to_renewal_policy?).with(active_policy, policy).and_return(false)
  end

  subject do
    EnrollmentAction::PlanChangeDependentAdd.new(termination_event, dependent_add_event)
  end

  it "publishes an event of type add dependents" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#change_product_member_add")
    subject.publish
  end

  it "clears all member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, dependent_add_event.hbx_enrollment_id, dependent_add_event.employer_hbx_id)
    subject.publish
  end

  it "publishes an auto renew event adding dependents on renewal policy" do
    subject.plan_change_dep_adding_to_renewal = true
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#auto_renew")
    subject.publish
  end
end

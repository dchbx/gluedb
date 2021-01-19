require 'rails_helper'

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 1) }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => [1,2]) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan, :all_member_ids => [1,2]) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::PlanChange }

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::PlanChange, "given an enrollment event set with invalid data" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 1) }
  let(:different_carrier_plan) { instance_double(Plan, :id => 3, carrier_id: 2) }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => [1,2]) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => new_plan, :all_member_ids => [1,2,3]) }
  let(:new_carrier_event) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => different_carrier_plan, :all_member_ids => [1,2]) }
  let(:event_set) { [event_1, event_2] }
  let(:invalid_event_set) { [event_1, event_2] }
  let(:carrier_change_set) { [event_1, new_carrier_event] }

  subject { EnrollmentAction::PlanChange }

  it "does not qualify with changed dependents" do
    expect(subject.qualifies?(event_set)).to be_falsey
  end

  it "does not qualify with unchanged plan" do
    expect(subject.qualifies?(invalid_event_set)).to be_falsey
  end

  it "does not qualify with changed carrier" do
    expect(subject.qualifies?(carrier_change_set)).to be_falsey
  end
end

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change" do
  let(:plan) { instance_double(Plan, :id => 1, carrier_id: 1) }
  let(:new_plan) { instance_double(Plan, :id => 2, carrier_id: 1) }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => [1], :policy_start => policy_start) }

  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => new_plan,
    :is_cobra? => false,
    :subscriber_start => new_enrollment_start
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :subscriber_end => termination_date
    ) }
  let(:new_enrollment_start) { DateTime.new(2017,3,1) }
  let(:policy_start) { DateTime.new(2017,1,1) }
  let(:termination_date) { DateTime.new(2017,2,28) }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }


  subject { EnrollmentAction::PlanChange.new(termination_event, plan_change_event) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).
      and_return(primary_db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, new_plan, false, market_from_payload: subject.action).
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

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change
--  is shop" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1,
    :is_shop? => true
    ) }

  subject { EnrollmentAction::PlanChange.new(nil, plan_change_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).
      and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").
      and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, plan_change_event.hbx_enrollment_id, plan_change_event.employer_hbx_id)
  end

  it "publishes an event of type change_product" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end


describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change
--  is not shop
--  has no renewal candidates" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1,
    :is_shop? => false
    ) }

  subject { EnrollmentAction::PlanChange.new(nil, plan_change_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).
      and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").
      and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, plan_change_event.hbx_enrollment_id, plan_change_event.employer_hbx_id)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(plan_change_event).and_return([])
  end

  it "publishes an event of type change_product" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change
--  is not shop
--  has renewal candidates
--  is not for 1/1 of next year" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1,
    :is_shop? => false
    ) }

  let(:now_time) do
    instance_double(
      Time,
      {
        year: 2018,
        month: 12,
        day: 15
      }
    )
  end

  let(:subscriber_start) do
    instance_double(
      Date,
      {
        year: 2018,
        month: 1,
        day: 1
      }
    )
  end

  let(:subscriber) { double }

  subject { EnrollmentAction::PlanChange.new(nil, plan_change_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).
      and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").
      and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, plan_change_event.hbx_enrollment_id, plan_change_event.employer_hbx_id)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(plan_change_event).and_return([1])
    allow(Time).to receive(:now).and_return(now_time)
    allow(plan_change_event).to receive(:subscriber).and_return(subscriber)
    allow(subject).to receive(:extract_enrollee_start).with(subscriber).and_return(subscriber_start)
  end

  it "publishes an event of type change_product" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change
--  is not shop
--  has renewal candidates
--  is for 1/1 of next year
--  today is after 12/20" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1,
    :is_shop? => false
    ) }

  let(:now_time) do
    instance_double(
      Time,
      {
        year: 2018,
        month: 12,
        day: 21
      }
    )
  end

  let(:subscriber_start) do
    instance_double(
      Date,
      {
        year: 2019,
        month: 1,
        day: 1
      }
    )
  end

  let(:subscriber) { double }

  subject { EnrollmentAction::PlanChange.new(nil, plan_change_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).
      and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").
      and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, plan_change_event.hbx_enrollment_id, plan_change_event.employer_hbx_id)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(plan_change_event).and_return([1])
    allow(Time).to receive(:now).and_return(now_time)
    allow(plan_change_event).to receive(:subscriber).and_return(subscriber)
    allow(subject).to receive(:extract_enrollee_start).with(subscriber).and_return(subscriber_start)
  end

  it "publishes an event of type change_product" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#change_product").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end

describe EnrollmentAction::PlanChange, "given an enrollment event set that:
--  provides a new plan id
--  with no dependents changed
--  with no carrier change
--  is not shop
--  has renewal candidates
--  is for 1/1 of next year
--  today is 12/20" do

  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:action_helper_result_xml) { double }
  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
    ) }
  let(:plan_change_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :employer_hbx_id => 1,
    :hbx_enrollment_id => 1,
    :is_shop? => false
    ) }

  let(:now_time) do
    instance_double(
      Time,
      {
        year: 2018,
        month: 12,
        day: 20
      }
    )
  end

  let(:subscriber_start) do
    instance_double(
      Date,
      {
        year: 2019,
        month: 1,
        day: 1
      }
    )
  end

  let(:subscriber) { double }

  subject { EnrollmentAction::PlanChange.new(nil, plan_change_event) }

  before :each do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).
      and_return(action_publish_helper)
    allow(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#active_renew").
      and_return(true)
    allow(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, plan_change_event.hbx_enrollment_id, plan_change_event.employer_hbx_id)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(plan_change_event).and_return([1])
    allow(Time).to receive(:now).and_return(now_time)
    allow(plan_change_event).to receive(:subscriber).and_return(subscriber)
    allow(subject).to receive(:extract_enrollee_start).with(subscriber).and_return(subscriber_start)
  end

  it "publishes an event of type active_renew" do
    expect(action_publish_helper).to receive(:set_event_action).
      with("urn:openhbx:terms:v1:enrollment#active_renew").and_return(true)
    subject.publish
  end

  it "clears member end dates" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([]).and_return(true)
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1).
      and_return(true)
    subject.publish
  end
end
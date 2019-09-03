require 'rails_helper'

describe EnrollmentAction::ActiveRenewal, "given an enrollment event set that:
-- is a single event
-- is not a termination
-- is not a passive renewal
-- has renewal candidates
-- has no changed dependents" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::ActiveRenewal }

  before do
    allow(subject).
      to receive(:same_carrier_renewal_candidates).
      with(event).
      and_return([member])
    allow(subject).
      to receive(:renewal_dependents_changed?).
      with(member, event).
      and_return(false)
  end
  it "qualifies" do
    expect(subject.qualifies?([event])).to be_truthy
  end
end

describe EnrollmentAction::ActiveRenewal, "given an enrollment event set that:
-- is a single event
-- is not a termination
-- is not a passive renewal
-- has renewal candidates
-- has changed dependents ##REJECT" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::ActiveRenewal }

  before do
    allow(subject).
      to receive(:same_carrier_renewal_candidates).
      with(event).
      and_return([member])
    allow(subject).
      to receive(:renewal_dependents_changed?).
      with(member, event).
      and_return(true)
  end

  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::ActiveRenewal, "given an enrollment event set that:
-- is a single event
-- is not a termination
-- is not a passive renewal
-- has no renewal candidates ##REJECT
-- has no changed dependents" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::ActiveRenewal }

  before do
    allow(subject).
      to receive(:same_carrier_renewal_candidates).
      with(event).
      and_return([])
    allow(subject).
      to receive(:renewal_dependents_changed?).
      with(member, event).
      and_return(true)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::ActiveRenewal, "given an enrollment event set that:
-- is a single event
-- is not a termination
-- is a passive renewal ##REJECT
-- has renewal candidates
-- has no changed dependents" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => true
                                ) }

  subject { EnrollmentAction::ActiveRenewal }

  before do
    allow(subject).
      to receive(:same_carrier_renewal_candidates).
      with(event).
      and_return([member])
    allow(subject).
      to receive(:renewal_dependents_changed?).
      with(member, event).
      and_return(false)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::ActiveRenewal, "given an enrollment event set that:
-- is a single event
-- is a termination ##REJECT
-- is not a passive renewal
-- has renewal candidates
-- has no changed dependents" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => true,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::ActiveRenewal }

  before do
    allow(subject).
      to receive(:same_carrier_renewal_candidates).
      with(event).
      and_return([member])
    allow(subject).
      to receive(:renewal_dependents_changed?).
      with(member, event).
      and_return(false)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::ActiveRenewal, "#persist" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :member => member) }

  let(:plan) { instance_double(Plan, :id => 1, year: Date.today.year, coverage_type: "health") }
  let(:policy_cv) { instance_double(Policy, :enrollees => [enrollee], market: "individual", plan: plan ) }

  let(:action) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => policy_cv ,
    :existing_plan => plan,
    :is_cobra? => false
    )
  }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }
  subject { EnrollmentAction::ActiveRenewal.new(nil,action) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member).and_return(db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(subject.action).to receive(:kind).and_return(action)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(policy_updater).to receive(:created_policy).and_return(policy_cv)
    allow(::Listeners::PolicyUpdatedObserver).to receive(:broadcast).and_return(nil)
  end

  context "successfuly persisted" do
    let(:db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

    before(:each) do
      allow(subject.action).to receive(:existing_policy).and_return(false)
    end

    it "returns true" do
      expect(subject.persist).to be_truthy
    end
  end
  context "failed to persist" do
    let(:db_record) { instance_double(ExternalEvents::ExternalMember, :persist => false) }

    before(:each) do
      allow(subject.action).to receive(:existing_policy).and_return(true)
    end

    it "returns false" do
      expect(subject.persist).to be_falsey
    end
  end
end

describe EnrollmentAction::ActiveRenewal, "#publish" do
  let(:amqp_connection) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:event_xml) { double }

  let(:action) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :event_responder => event_responder,
    :event_xml => event_xml,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
    )
  }
  let(:action_helper_result_xml) { double }

  let(:action_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  subject { EnrollmentAction::ActiveRenewal.new(nil,action) }

  before do
    allow(EnrollmentAction::ActionPublishHelper).
      to receive(:new).
      with(event_xml).and_return(action_helper)
    allow(action_helper).
      to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew").
      and_return(true)
    allow(action_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1)
  end

  it "publishes an event of type active renew" do
    expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew")
    subject.publish
  end

  it "clears member end dates" do
    expect(action_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).
      to receive(:publish_edi).
      with(amqp_connection, action_helper_result_xml, 1, 1)
    subject.publish
  end
end

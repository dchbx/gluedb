require 'rails_helper'

describe EnrollmentAction::RenewalDependentAdd, "given an enrollment event set that:
-- is not a termination
-- is not a passive renewal
-- has renewal candidates
-- dependents added" do
  let(:member) { double(:active_member_ids => [1]) }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false,
                                  :all_member_ids => [1,2]
                                ) }

  subject { EnrollmentAction::RenewalDependentAdd }

  before do
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event).and_return([member])
    allow(subject).to receive(:renewal_dependents_added?).with(member, event).and_return(true)
  end
  it "qualifies" do
    expect(subject.qualifies?([event])).to be_truthy
  end
end


describe EnrollmentAction::RenewalDependentAdd, "given an enrollment event set that:
-- is not a termination
-- is not a passive renewal
-- has no dependent renewal candidates ##REJECT
-- dependents added" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::RenewalDependentAdd }

  before do
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event).and_return([])
    allow(subject).to receive(:renewal_dependents_added?).with(member, event).and_return(true)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::RenewalDependentAdd, "given an enrollment event set that:
-- is not a termination
-- is a passive renewal ##REJECT
-- has dependent renewal candidates
-- dependents added" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => false,
                                  :is_passive_renewal? => true
                                ) }

  subject { EnrollmentAction::RenewalDependentAdd }

  before do
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event).and_return([member])
    allow(subject).to receive(:renewal_dependents_added?).with(member, event).and_return(false)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::RenewalDependentAdd, "given an enrollment event set that:
-- is a termination ##REJECT
-- is not a passive renewal
-- has dependent renewal candidates
-- dependents added" do
  let(:member) { double() }
  let(:event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :is_termination? => true,
                                  :is_passive_renewal? => false
                                ) }

  subject { EnrollmentAction::RenewalDependentAdd }

  before do
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event).and_return([member])
    allow(subject).to receive(:renewal_dependents_added?).with(member, event).and_return(false)
  end
  it "does not qualify" do
    expect(subject.qualifies?([event])).to be_falsey
  end
end

describe EnrollmentAction::RenewalDependentAdd, "#persist" do
  let(:member) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee) { instance_double(::Openhbx::Cv2::Enrollee, :member => member) }

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy_cv) { instance_double(Policy, :enrollees => [enrollee]) }

  let(:action) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => policy_cv,
    :existing_plan => plan,
    :is_cobra? => false
    )
  }
  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }
  subject { EnrollmentAction::RenewalDependentAdd.new(nil,action) }

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member).and_return(db_record)
    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(policy_cv, plan, false, market_from_payload: subject.action).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
    allow(subject.action).to receive(:kind).and_return(action)
  end

  context "successfuly persisted" do
    let(:db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

    it "returns true" do
      expect(subject.persist).to be_truthy
    end
  end
  context "failed to persist" do
    let(:db_record) { instance_double(ExternalEvents::ExternalMember, :persist => false) }

    it "returns false" do
      expect(subject.persist).to be_falsey
    end
  end
end

describe EnrollmentAction::RenewalDependentAdd, "#publish" do
  let(:amqp_connection) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:event_xml) { double }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:enrollee_primary) { instance_double(Openhbx::Cv2::Enrollee, :member => member_primary, :subscriber? => true) }
  let(:enrollee_affected) { instance_double(Enrollee, :m_id => 1)}
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }

  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary]) }

  let(:renewal_dependent_add_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :all_member_ids => [1,2],
    :event_responder => event_responder,
    :event_xml => event_xml,
    :policy_cv => new_policy_cv,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }
  let(:action_helper_result_xml) { double }

  let(:action_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }
  let(:renewal_enrollees) { double(enrollees: [enrollee_affected]) }
  subject { EnrollmentAction::RenewalDependentAdd.new(nil,renewal_dependent_add_event) }

  before do
    allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_helper)
    allow(action_helper).to receive(:filter_affected_members).with([2]).and_return(true)
    allow(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew_member_add").and_return(true)
    allow(action_helper).to receive(:keep_member_ends).with([]).and_return(true)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, renewal_dependent_add_event.hbx_enrollment_id, renewal_dependent_add_event.employer_hbx_id)
    allow(subject.class).to receive(:same_carrier_renewal_candidates).with(renewal_dependent_add_event).and_return([renewal_enrollees])
    allow(renewal_dependent_add_event).to receive(:renewal_cancel_policy).and_return([])
  end

  it "publishes an event of type renew dependent add" do
    expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew_member_add")
    subject.publish
  end

  it "filters dependents filter affected members" do
    expect(action_helper).to receive(:filter_affected_members).with([2])
    subject.publish
  end

  it "clears member end dates" do
    expect(action_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes the xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, 1, 1)
    subject.publish
  end

  context "carrier with canceled_renewal_causes_new_coverage" do
    let(:carrier) { instance_double(Carrier, :canceled_renewal_causes_new_coverage => true) }
    let(:policy) { instance_double(Policy, :carrier => carrier) }

    before do
      allow(EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_helper)
      allow(action_helper).to receive(:filter_affected_members).with([2]).and_return(true)
      allow(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew_member_add").and_return(true)
      allow(action_helper).to receive(:keep_member_ends).with([]).and_return(true)
      allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, renewal_dependent_add_event.hbx_enrollment_id, renewal_dependent_add_event.employer_hbx_id)
      allow(subject.class).to receive(:same_carrier_renewal_candidates).with(renewal_dependent_add_event).and_return([renewal_enrollees])
      allow(renewal_dependent_add_event).to receive(:renewal_cancel_policy).and_return(true)
      allow(renewal_dependent_add_event).to receive(:existing_policy).and_return(policy)
    end

    it "publishes an event of type initial" do
      expect(action_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
      subject.publish
    end
  end
end

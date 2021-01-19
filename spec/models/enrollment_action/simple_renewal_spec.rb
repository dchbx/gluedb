require "rails_helper"

describe EnrollmentAction::SimpleRenewal, "Simple Renewal", dbclean: :after_each do

  let(:carrier) { instance_double(Carrier, :id => 1, :requires_simple_renewal? => true) }
  let(:plan_1) { instance_double(Plan, :id => 1, :carrier_id => 1) }
  let(:member_ids_1) { [1,2] }
  let(:policy_cv) { double()}
  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification,
                                  :existing_plan => plan_1,
                                  :all_member_ids => member_ids_1,
                                  :is_termination? => false,
                                  :is_passive_renewal? => false,
                                  :is_shop? => true,
                                  :policy_cv => policy_cv
                                 ) }
  let(:event_set) { [event_1] }
  let(:same_carrier_renewal_candidates) { double }

  subject { EnrollmentAction::SimpleRenewal }

  before :each do
    allow(plan_1).to receive(:carrier).and_return(carrier)
    allow(subject).to receive(:same_carrier_renewal_candidates).with(event_1).and_return([same_carrier_renewal_candidates])
    allow(subject).to receive(:extract_plan).with(policy_cv).and_return(plan_1)
  end

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end

  it "When does not qualifies" do
    allow(carrier).to receive(:requires_simple_renewal?).and_return(false)
    expect(subject.qualifies?(event_set)).to be_falsey
  end
end

describe EnrollmentAction::SimpleRenewal, "given a qualified enrollment set, being persisted", dbclean: :after_each do
  let(:carrier) { instance_double(Carrier, :id => 1, :requires_simple_renewal? => true) }
  let(:member_primary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 1) }
  let(:member_secondary) { instance_double(Openhbx::Cv2::EnrolleeMember, id: 2) }
  let(:enrollee_primary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_primary) }
  let(:enrollee_secondary) { instance_double(::Openhbx::Cv2::Enrollee, :member => member_secondary) }

  let(:new_policy_cv) { instance_double(Openhbx::Cv2::Policy, :enrollees => [enrollee_primary, enrollee_secondary]) }
  let(:plan) { instance_double(Plan, :id => 1, :carrier_id => 1) }
  let(:primary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:secondary_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:new_db_record) { instance_double(ExternalEvents::ExternalMember, :persist => true) }
  let(:subscriber_start) { Date.today }
  let(:subscriber_end) { subscriber_start - 1.day }
  let(:terminated_member_ids) { [1, 2] }

  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :policy_cv => new_policy_cv,
    :existing_plan => plan,
    :all_member_ids => [1,2],
    :hbx_enrollment_id => 3,
    :subscriber_start => subscriber_start,
    :is_cobra? => false,
    :is_shop? => true
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicy) }
  let(:same_carrier_term_candidate) { instance_double(Policy, :active_member_ids => terminated_member_ids) }

  subject do
    EnrollmentAction::SimpleRenewal.new(nil, action_event)
  end

  before :each do
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_primary).and_return(primary_db_record)
    allow(ExternalEvents::ExternalMember).to receive(:new).with(member_secondary).and_return(secondary_db_record)

    allow(ExternalEvents::ExternalPolicy).to receive(:new).with(new_policy_cv, plan, false).and_return(policy_updater)
    allow(policy_updater).to receive(:persist).and_return(true)
    allow(EnrollmentAction::SimpleRenewal).to receive(:same_carrier_renewal_candidates).with(action_event).and_return([same_carrier_term_candidate])
    allow(same_carrier_term_candidate).to receive(:terminate_as_of).with(subscriber_end).and_return(true)
    allow(subject.action).to receive(:existing_policy).and_return(false)
  end

  it "successfully creates the new policy" do
    expect(subject.persist).to be_truthy
  end

  it "terminates the old carrier policy" do
    expect(same_carrier_term_candidate).to receive(:terminate_as_of).with(subscriber_end).and_return(true)
    subject.persist 
  end

  it "assigns the termination information" do
    subject.persist 
    expect(subject.terminated_policy_information).to eq [[same_carrier_term_candidate, [1,2]]]
  end
end

describe EnrollmentAction::SimpleRenewal, "given a qualified enrollment set for termination, and a new enrollment, being published", dbclean: :after_each do
  let(:amqp_connection) { double }
  let(:event_xml) { double }
  let(:event_responder) { instance_double(::ExternalEvents::EventResponder, :connection => amqp_connection) }
  let(:enrollee_primary) { double(:m_id => 1, :coverage_start => :one_month_ago) }
  let(:enrollee_new) { double(:m_id => 2, :coverage_start => :one_month_ago) }

  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :enrollees => [enrollee_primary, enrollee_new], :eg_id => 1) }

  let(:action_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :event_xml => event_xml,
    :all_member_ids => [1,2],
    :event_responder => event_responder,
    :hbx_enrollment_id => 1,
    :employer_hbx_id => 1
  ) }

  let(:termination_helper_result_xml) { double }
  let(:termination_writer_result_xml) { double }

  let(:termination_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => termination_helper_result_xml
  ) }

  let(:action_helper_result_xml) { double }

  let(:action_publish_helper) { instance_double(
    EnrollmentAction::ActionPublishHelper,
    :to_xml => action_helper_result_xml
  ) }

  let(:termination_writer) {
    instance_double(::EnrollmentAction::EnrollmentTerminationEventWriter)
  }

  let(:employer_hbx_id) { double }
  let(:terminated_policy_eg_id) { double }
  let(:employer) { instance_double(Employer, :hbx_id => employer_hbx_id) }

  let(:terminated_policy) {
    instance_double(Policy, :eg_id => terminated_policy_eg_id, :employer => employer)
  }

  subject do
    EnrollmentAction::SimpleRenewal.new(nil, action_event).tap do |s|
      s.terminated_policy_information = [[terminated_policy, [1,2]]]
    end
  end

  before :each do
    allow(::EnrollmentAction::EnrollmentTerminationEventWriter).to receive(:new).with(terminated_policy, [1,2]).and_return(termination_writer)
    allow(termination_writer).to receive(:write).with("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#terminate_enrollment").and_return(termination_writer_result_xml)
    allow(::EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
    allow(::EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_writer_result_xml).and_return(termination_publish_helper)
    allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, terminated_policy_eg_id, employer_hbx_id)
    allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, action_event.hbx_enrollment_id, action_event.employer_hbx_id)
    allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew")
    allow(action_publish_helper).to receive(:keep_member_ends).with([])
    allow(action_event).to receive(:renewal_cancel_policy).and_return([])
  end

  it "publishes an event of enrollment termination" do
    expect(termination_writer).to receive(:write).with("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#terminate_enrollment").and_return(termination_writer_result_xml)
    subject.publish
  end

  it "publishes termination resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, terminated_policy_eg_id, employer_hbx_id)
    subject.publish
  end

  it "clears all member end dates before publishing" do
    expect(action_publish_helper).to receive(:keep_member_ends).with([])
    subject.publish
  end

  it "publishes an event of enrollment active renewing" do
    expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew")
    subject.publish
  end

  it "publishes active renewing resulting xml to edi" do
    expect(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, action_event.hbx_enrollment_id, action_event.employer_hbx_id)
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

  context "carrier with canceled_renewal_causes_new_coverage" do
    let(:carrier) { instance_double(Carrier, :canceled_renewal_causes_new_coverage => true) }
    let(:policy) { instance_double(Policy, :carrier => carrier) }

    before do
      allow(::EnrollmentAction::EnrollmentTerminationEventWriter).to receive(:new).with(terminated_policy, [1,2]).and_return(termination_writer)
      allow(termination_writer).to receive(:write).with("transaction_id_placeholder", "urn:openhbx:terms:v1:enrollment#terminate_enrollment").and_return(termination_writer_result_xml)
      allow(::EnrollmentAction::ActionPublishHelper).to receive(:new).with(event_xml).and_return(action_publish_helper)
      allow(::EnrollmentAction::ActionPublishHelper).to receive(:new).with(termination_writer_result_xml).and_return(termination_publish_helper)
      allow(subject).to receive(:publish_edi).with(amqp_connection, termination_helper_result_xml, terminated_policy_eg_id, employer_hbx_id)
      allow(subject).to receive(:publish_edi).with(amqp_connection, action_helper_result_xml, action_event.hbx_enrollment_id, action_event.employer_hbx_id)
      allow(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#active_renew")
      allow(action_publish_helper).to receive(:keep_member_ends).with([])
      allow(action_event).to receive(:renewal_cancel_policy).and_return(true)
      allow(action_event).to receive(:existing_policy).and_return(policy)
    end

    it "publishes an event of type initial" do
      expect(action_publish_helper).to receive(:set_event_action).with("urn:openhbx:terms:v1:enrollment#initial")
      subject.publish
    end
  end
end

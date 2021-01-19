require "rails_helper"

describe EnrollmentAction::ReselectionOfExistingCoverage, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a cancel for plan A
- the second enrollment is a start for plan A
- the second enrollment has the same number of members" do

  let(:plan) { instance_double(Plan, :id => 1) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::ReselectionOfExistingCoverage}
  before do
    allow(event_1).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
    allow(event_2).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
  end

  it "qualifies" do
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end

describe EnrollmentAction::ReselectionOfExistingCoverage, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a cancel for plan A
- the second enrollment is a start for plan A
- the second enrollment has a different number of members" do

  let(:plan) { instance_double(Plan, :id => 1) }

  let(:member_ids_1) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::ReselectionOfExistingCoverage}

  before do
    allow(event_1).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
    allow(event_2).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
  end

  describe "the second enrollment has more members" do
    let(:member_ids_2) { [1,2,3] }
    it "does not qualify" do
      expect(subject.qualifies?(event_set)).to be_falsey
    end
  end

  describe "the second enrollment has less members" do
    let(:member_ids_2) { [1] }
    it "does not qualify" do
      expect(subject.qualifies?(event_set)).to be_falsey
    end
  end
end

describe EnrollmentAction::ReselectionOfExistingCoverage, "given an enrollment event set that:
- has two enrollments
- the first enrollment is a cancel for plan A
- the second enrollment is a start for plan B
- the second enrollment has the same number of members" do

  let(:plan_1) { instance_double(Plan, :id => 1) }
  let(:plan_2) { instance_double(Plan, :id => 2) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan_1, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan_2, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::ReselectionOfExistingCoverage}

  before do
    allow(event_1).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
    allow(event_2).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return true
  end

  it "does not qualify" do
    expect(subject.qualifies?(event_set)).to be_falsey
  end
end

describe EnrollmentAction::ReselectionOfExistingCoverage, "market changes" do
  let(:plan) { instance_double(Plan, :id => 1) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::ReselectionOfExistingCoverage}

  it "qualifies" do
    allow(event_1).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return 'ivl'
    allow(event_2).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return 'coveall'
    expect(subject.qualifies?(event_set)).to be_falsey
  end
end

describe EnrollmentAction::ReselectionOfExistingCoverage, "the same market" do
  let(:plan) { instance_double(Plan, :id => 1) }

  let(:member_ids_1) { [1,2] }
  let(:member_ids_2) { [1,2] }

  let(:event_1) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_1) }
  let(:event_2) { instance_double(ExternalEvents::EnrollmentEventNotification, :existing_plan => plan, :all_member_ids => member_ids_2) }
  let(:event_set) { [event_1, event_2] }

  subject { EnrollmentAction::ReselectionOfExistingCoverage}

  it "does not qualify" do
    allow(event_1).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return 'ivl'
    allow(event_2).to receive_message_chain("enrollment_event_xml.event.body.enrollment.market").and_return 'ivl'
    expect(subject.qualifies?(event_set)).to be_truthy
  end
end


describe EnrollmentAction::ReselectionOfExistingCoverage, "given a qualified enrollment set, being persisted" do
  let(:plan) { instance_double(Plan, :id => 1) }
  let(:policy) { instance_double(Policy, :hbx_enrollment_ids => existing_hbx_enrollment_ids) }

  let(:new_purchase_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :hbx_enrollment_id => 3
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification,
    :existing_policy => policy,
    :all_member_ids => [1,2]
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberAdd) }
  let(:existing_hbx_enrollment_ids) { double }


  subject do
    EnrollmentAction::ReselectionOfExistingCoverage.new(termination_event, new_purchase_event)
  end

  before :each do
    allow(policy).to receive(:save).and_return(true)
    allow(existing_hbx_enrollment_ids).to receive(:<<).with(3)
  end

  it "adds the new hbx_enrollment_id to the existing policy" do
    expect(existing_hbx_enrollment_ids).to receive(:<<).with(3)
    subject.persist
  end

  it "persists successfully" do
    expect(subject.persist).to be_truthy
  end
end

describe EnrollmentAction::ReselectionOfExistingCoverage, "given a qualified enrollment set, being published" do
  let(:new_purchase_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification
    ) }
  let(:termination_event) { instance_double(
    ::ExternalEvents::EnrollmentEventNotification
    ) }

  let(:policy_updater) { instance_double(ExternalEvents::ExternalPolicyMemberAdd) }
  let(:existing_hbx_enrollment_ids) { double }


  subject do
    EnrollmentAction::ReselectionOfExistingCoverage.new(termination_event, new_purchase_event)
  end

  it "has no errors" do
    expect(subject.publish.last).to eq({})
  end

  it "always completes successfully" do
    expect(subject.publish.first).to be_truthy
  end
end

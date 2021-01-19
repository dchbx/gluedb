require "rails_helper"

describe EnrollmentAction::ReinstatementComparisonHelper do
  subject { Class.new { extend EnrollmentAction::ReinstatementComparisonHelper } }

  describe "shop_reinstatement_candidate?" do
    ## receives a policy, plan, employer, subscriber_id, subscriber_start, and a boolean if same carrier
    let(:subscriber) { double(:m_id => 1)}
    let(:employer) { double(id: 1) }
    let(:policy_employer_id) { 1 }
    let(:old_plan) { instance_double(Plan, :year => 2016, :carrier_id => 1, :coverage_type => :some_type)}
    let(:new_plan) { instance_double(Plan, :year => 2016, :carrier_id => 1, :coverage_type => :some_type) }
    let(:same_carrier) { true }
    let(:canceled?) { false }
    let(:terminated?) { false }
    let(:subscriber_id) { 1 }
    let(:subscriber_start) { DateTime.new(2017,1,1) }
    let(:old_coverage_period) { double(:end => subscriber_start - 1.day) }

    let(:policy) { instance_double(Policy,
                    :terminated? => terminated?,
                    :canceled? => canceled?,
                    :subscriber => subscriber,
                    :employer_id => policy_employer_id,
                    :plan => old_plan,
                    :coverage_period => old_coverage_period)
                  }

    it "returns true for the matching cases" do
      expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_truthy
    end

    context "the policy does not include an employer_id" do
      let(:policy_employer_id) { nil }
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "the policy subscriber is blank" do
      let(:subscriber) { nil }
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "the policy's subscriber member id does not match the new subscriber_id" do
      let(:subscriber) { instance_double(Enrollee, :m_id => 4) }
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "the policy coverage type changed" do
      let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 1, :coverage_type => :new_type)}
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "the employer does not match" do
      let(:policy_employer_id) { 2 }
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "the plan years dont align" do
      let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 1, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "carrier changed" do
      let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 2, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end

    context "returns false if there is a gap between coverage end and subscriber_start" do
      let(:old_coverage_period) { double(:end => subscriber_start - 2.day) }
      it "returns false" do
        expect(subject.shop_reinstatement_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start)).to be_falsey
      end
    end
  end

  describe "shop_reinstatement_candidates" do
    let(:policy_cv) { double }
    let(:subscriber_enrollee) { instance_double(Enrollee) }
    let(:subscriber_start) { DateTime.new(2017,1,1) }
    let(:subscriber_id) { 1 }
    let(:subscriber_person) { instance_double(Person, :policies => [:policy, :non_eligible_policy]) }
    let(:employer) { instance_double(Employer) }
    let(:plan_year) { double(:end_date => subscriber_start + 1.month) }

    before do
      allow(subject).to receive(:extract_subscriber).with(policy_cv).and_return(subscriber_enrollee)
      allow(subject).to receive(:extract_enrollee_start).with(subscriber_enrollee).and_return(subscriber_start)
      allow(subject).to receive(:extract_member_id).with(subscriber_enrollee).and_return(subscriber_id)
      allow(subject).to receive(:find_employer).with(policy_cv).and_return(:employer)
      allow(subject).to receive(:find_employer_plan_year).with(policy_cv).and_return(plan_year)
      allow(subject).to receive(:extract_enrollee_end).with(subscriber_enrollee).and_return('')
      allow(Person).to receive(:find_by_member_id).with(subscriber_id).and_return(subscriber_person)
      allow(subject).to receive(:extract_plan).with(policy_cv).and_return(:plan)
      allow(subject).to receive(:shop_reinstatement_candidate?).
        with(:policy, :plan, :employer, 1, subscriber_start).and_return(true)
      allow(subject).to receive(:shop_reinstatement_candidate?).
        with(:non_eligible_policy, :plan, :employer, 1, subscriber_start).and_return(false)
    end
    it "sends :shop_reinstatement_candidate? for each policy and returns a candidate if true" do
      expect(subject).to receive(:shop_reinstatement_candidate?).
        with(:policy, :plan, :employer, 1, subscriber_start).once
      expect(subject.shop_reinstatement_candidates(policy_cv)).to eq([:policy])
    end
  end

  describe "#is_continuation_of_coverage_event?" do
    let(:policy_cv) { instance_double(Openhbx::Cv2::Policy, :previous_policy_id => previous_policy_id) }
    let(:enrollment_action) { instance_double(ExternalEvents::EnrollmentEventNotification, :policy_cv => policy_cv) }

    describe "given a policy that does not have a previous policy id" do
      let(:previous_policy_id) { nil }

      it "is false" do
        expect(subject.is_continuation_of_coverage_event?(enrollment_action)).to be_falsey
      end
    end

    describe "given a policy that has a previous policy id" do
      let(:previous_policy_id) { "SOME POLICY ID" }

      it "is true" do
        expect(subject.is_continuation_of_coverage_event?(enrollment_action)).to be_truthy
      end
    end
  end
end

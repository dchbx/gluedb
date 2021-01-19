require "rails_helper"

describe EnrollmentAction::RenewalComparisonHelper do
  subject { Class.new { extend EnrollmentAction::RenewalComparisonHelper } }

  describe "#any_renewal_candidates?" do
    let(:enrollment_event) { double }
    let(:same_carrier_candidates) { [] }
    let(:other_carrier_candidates) { [] }

    before do
      allow(subject).to receive(:same_carrier_renewal_candidates).with(enrollment_event).and_return(same_carrier_candidates)
      allow(subject).to receive(:other_carrier_renewal_candidates).with(enrollment_event).and_return(other_carrier_candidates)
    end

    it "returns false" do
      expect(subject.any_renewal_candidates?(enrollment_event)).to be_falsey
    end

    context "with same carrier candidates" do
      let(:same_carrier_candidates) { [:candidate] }
      it "returns true" do
        expect(subject.any_renewal_candidates?(enrollment_event)).to be_truthy
      end
    end

    context "with other carrier candidates" do
      let(:other_carrier_candidates) { [:candidate] }
      it "returns true" do
        expect(subject.any_renewal_candidates?(enrollment_event)).to be_truthy
      end
    end
  end

  describe "#carrier_requires_simple_renewal" do
    let(:carrier) { instance_double(Carrier, :id => 1, :requires_simple_renewal? => false) }
    let(:plan) { instance_double(Plan, :id => 1, :carrier_id => 1) }
    let(:is_shop?) { false }
    let(:policy_cv) { double()}
    let(:enrollment_event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                              :existing_plan => plan,
                              :is_shop? => is_shop?,
                              :policy_cv => policy_cv
                               )}
    before :each do
      allow(plan).to receive(:carrier).and_return(carrier)
      allow(subject).to receive(:extract_plan).with(policy_cv).and_return(plan)
    end

    it "returns false" do
      expect(subject.carrier_requires_simple_renewal?(enrollment_event)).to be_falsey
    end

    it "returns true" do
      allow(carrier).to receive(:requires_simple_renewal?).and_return(true)
      expect(subject.carrier_requires_simple_renewal?(enrollment_event)).to be_truthy
    end
  end

  describe "#same_carrier_renewal_candidates" do
    let(:is_shop?) { false }
    let(:policy_cv) { double()}
    let(:enrollment_event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                              :is_shop? => is_shop?,
                              :policy_cv => policy_cv
                               )}
    let(:plan) { instance_double(Plan) }
    let(:policy) { instance_double(Policy) }
    let(:subscriber_person) { double(:policies => [policy]) }
    before do
      allow(subject).to receive(:extract_ivl_policy_details).with(policy_cv).
        and_return([plan, subscriber_person, :subscriber_id, :subscriber_start])
      allow(subject).to receive(:ivl_renewal_candidate?).with(policy, plan, :subscriber_id, :subscriber_start, true).
        and_return(true)
    end
    it "returns true" do
      expect(subject.same_carrier_renewal_candidates(enrollment_event)).to eq([policy])
    end

    context "with an empty subscriber_person" do
      let(:subscriber_person) { nil }
      it "returns an empty array" do
        expect(subject.same_carrier_renewal_candidates(enrollment_event)).to eq([])
      end
    end
    context "if the enrollment event is SHOP" do
      let(:is_shop?) { true }
      before do
        allow(subject).to receive(:shop_renewal_candidates).with(policy_cv, true).and_return([:policy])
      end
      it "checks the shop_renewal_candidates" do
        expect(subject.same_carrier_renewal_candidates(enrollment_event)).to eq([:policy])
      end
    end
  end

  describe "#renewal_dependents_changed?" do
    let(:enrollment_event) { instance_double(ExternalEvents::EnrollmentEventNotification) }
    let(:renewal_candidate) { double }
    let(:dropped) { false }
    let(:added) { false }

    before do
      allow(subject).to receive(:renewal_dependents_added?).
        with(renewal_candidate, enrollment_event).
        and_return(added)
      allow(subject).to receive(:renewal_dependents_dropped?).
        with(renewal_candidate, enrollment_event).
        and_return(dropped)
    end

    it "returns false" do
      expect(subject.renewal_dependents_changed?(renewal_candidate, enrollment_event))
    end

    context "if dependends have been added" do
      let(:added) { true }
      it "returns true" do
        expect(subject.renewal_dependents_changed?(renewal_candidate, enrollment_event))
      end
    end
    context "if dependends have been dropped" do
      let(:dropped) { true }
      it "returns true" do
        expect(subject.renewal_dependents_changed?(renewal_candidate, enrollment_event))
      end
    end
  end

  describe "#renewal_dependents_added?" do
    let(:all_member_ids) { [1,2,3] }
    let(:enrollment_event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                              :all_member_ids => all_member_ids
                              )
                           }
    let(:renewal_candidate) { double(:active_member_ids => [1,2,3]) }

    it "returns false if there are no added ids" do
      expect(subject.renewal_dependents_added?(renewal_candidate, enrollment_event)).to be_falsey
    end

    context "if there are added members" do
      let(:all_member_ids) { [1,2,3,4] }
      it "returns true" do
        expect(subject.renewal_dependents_added?(renewal_candidate, enrollment_event)).to be_truthy
      end
    end

    context "if there are dropped members" do
      let(:all_member_ids) { [1,2] }
      it "returns false" do
        expect(subject.renewal_dependents_added?(renewal_candidate, enrollment_event)).to be_falsey
      end
    end
  end

  describe "#renewal_dependents_dropped?" do
    let(:all_member_ids) { [1,2,3] }
    let(:enrollment_event) { instance_double(ExternalEvents::EnrollmentEventNotification,
                              :all_member_ids => all_member_ids
                              )
                           }
    let(:renewal_candidate) { double(:active_member_ids => [1,2,3]) }

    it "returns false if there are no dropped ids" do
      expect(subject.renewal_dependents_dropped?(renewal_candidate, enrollment_event)).to be_falsey
    end

    context "if there are added members" do
      let(:all_member_ids) { [1,2,3,4] }
      it "returns false" do
        expect(subject.renewal_dependents_dropped?(renewal_candidate, enrollment_event)).to be_falsey
      end
    end

    context "if there are dropped members" do
      let(:all_member_ids) { [1,2] }
      it "returns true" do
        expect(subject.renewal_dependents_dropped?(renewal_candidate, enrollment_event)).to be_truthy
      end
    end
  end

  describe "ivl_renewal_candidate?" do
    let(:subscriber) { instance_double(Enrollee, :m_id => 1)}
    let(:subscriber_id) { 1 }
    let(:is_shop?) { false }
    let(:canceled?) { false }
    let(:terminated?) { false }
    let(:same_carrier) { true }
    let(:old_plan) { instance_double(Plan, :year => 2016, :carrier_id => 1, :coverage_type => :some_type)}
    let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 1, :coverage_type => :some_type) }
    let(:policy) { instance_double(Policy,
                    :is_shop? => is_shop?,
                    :subscriber => subscriber,
                    :plan => old_plan,
                    :canceled? => canceled?,
                    :terminated? => terminated?,
                    :coverage_period => old_coverage_period )
                  }
    let(:subscriber_start) { DateTime.new(2017,1,1) }
    let(:old_coverage_period) { double(:end => subscriber_start - 1.day) }

    it "returns true" do
      expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_truthy
    end

    context "policy is for SHOP" do
      let(:is_shop?) { true }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "policy subscriber mismatch" do
      let(:subscriber_id) { 2 }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "plan year mismatch" do
      let(:old_plan) { instance_double(Plan, :year => 2015, :carrier_id => 1, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "coverage type mismatch" do
      let(:old_plan) { instance_double(Plan, :year => 2016, :carrier_id => 1, :coverage_type => :different_type)}
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "carrier change but same_carrier is true" do
      let(:old_plan) { instance_double(Plan, :year => 2016, :carrier_id => 2, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "carrier unchanged but same_carrier is false" do
      let(:same_carrier) { false }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "policy cancelled" do
      let(:canceled?) { true }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "policy terminated" do
      let(:terminated?) { true }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
    context "start date and end date gap" do
      let(:old_coverage_period) { double(:end => subscriber_start - 2.day) }
      it "returns false" do
        expect(subject.ivl_renewal_candidate?(policy, new_plan, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
  end
  describe "shop_renewal_candidate?" do
    ## receives a policy, plan, employer, subscriber_id, subscriber_start, and a boolean if same carrier
    let(:subscriber) { double(:m_id => 1)}
    let(:employer) { double(id: 1) }
    let(:policy_employer_id) { 1 }
    let(:old_plan) { instance_double(Plan, :year => 2016, :carrier_id => 1, :coverage_type => :some_type)}
    let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 1, :coverage_type => :some_type) }
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
      expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_truthy
    end

    context "the policy does not include an employer_id" do
      let(:policy_employer_id) { nil }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the policy is cancelled" do
      let(:canceled?) { true }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the policy is terminated" do
      let(:terminated?) { true }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the policy subscriber is blank" do
      let(:subscriber) { nil }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the policy's subscriber member id does not match the new subscriber_id" do
      let(:subscriber) { instance_double(Enrollee, :m_id => 4) }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the policy coverage type changed" do
      let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 1, :coverage_type => :new_type)}
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the employer does not match" do
      let(:policy_employer_id) { 2 }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "the plan years dont align" do
      let(:new_plan) { instance_double(Plan, :year => 2018, :carrier_id => 1, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "carrier unchanged but same_carrier is false" do
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, false)).to be_falsey
      end
    end

    context "carrier changed but same_carrier is true" do
      let(:new_plan) { instance_double(Plan, :year => 2017, :carrier_id => 2, :coverage_type => :some_type)}
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end

    context "returns false if there is a gap between coverage end and subscriber_start" do
      let(:old_coverage_period) { double(:end => subscriber_start - 2.day) }
      it "returns false" do
        expect(subject.shop_renewal_candidate?(policy, new_plan, employer, subscriber_id, subscriber_start, same_carrier)).to be_falsey
      end
    end
  end

  describe "shop_renewal_candidates" do
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
      allow(subject).to receive(:shop_renewal_candidate?).
        with(:policy, :plan, :employer, 1, subscriber_start, true).and_return(true)
      allow(subject).to receive(:shop_renewal_candidate?).
        with(:non_eligible_policy, :plan, :employer, 1, subscriber_start, true).and_return(false)
    end
    it "sends :shop_renewal_candidate? for each policy and returns a candidate if true" do
      expect(subject).to receive(:shop_renewal_candidate?).
        with(:policy, :plan, :employer, 1, subscriber_start, true).once
      expect(subject.shop_renewal_candidates(policy_cv, true)).to eq([:policy])
    end
  end
end

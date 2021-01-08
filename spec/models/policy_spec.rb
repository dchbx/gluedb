require 'rails_helper'

describe Policy, :dbclean => :after_each do
  subject(:policy) { build(:policy) }

  [
    :eg_id,
    :preceding_enrollment_group_id,
    :allocated_aptc,
    :elected_aptc,
    :applied_aptc,
    :csr_amt,
    :pre_amt_tot,
    :tot_res_amt,
    :tot_emp_res_amt,
    :sep_reason,
    :carrier_to_bill,
    :aasm_state,
    :enrollees,
    :carrier,
    :broker,
    :plan,
    :carrier_specific_plan_id,
    :rating_area,
    :composite_rating_tier,
    :employer,
    :responsible_party,
    :transaction_set_enrollments,
    :federal_transmissions,
    :premium_payments
  ].each do |attribute|
    it { should respond_to attribute }
  end

  describe "created with a factory" do
    subject { create(:policy) }

    it "has the correct default hbx_enrollment_ids" do
      expect(subject.hbx_enrollment_ids).to eq [subject.eg_id]
    end

    it "has the correct default carrier_to_bill value" do
      expect(subject.carrier_to_bill).to eq(true)
    end

    it "has the correct rating_area value" do
      expect(subject.rating_area).to eq "100"
      subject.update_attributes(rating_area: "101")
      expect(subject.rating_area).to eq "101"
    end
  end

  describe '#subscriber' do
    let(:enrollee) { build(:enrollee, relationship_status_code: relationship) }
    before { policy.enrollees = [ enrollee ] }

    context 'given no enrollees with relationship of self' do
      let(:relationship) { 'child' }
      it 'returns nil' do
        expect(policy.subscriber).to eq nil
      end
    end

    context 'given an enrollee with relationship of self' do
      let(:relationship) { 'self' }
      it 'returns nil' do
        expect(policy.subscriber).to eq enrollee
      end
    end
  end

  describe '#has_responsible_person?' do
    context 'no responsible party ID is set' do
      before { policy.responsible_party_id = nil }

      it 'return false' do
        expect(policy.has_responsible_person?).to be_false
      end
    end

    context 'responsible party ID is set' do
      before { policy.responsible_party_id = 2 }

      it 'return true' do
        expect(policy.has_responsible_person?).to be_true
      end
    end
  end

  describe '#responsible_person' do
    let(:id) { 1 }
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:responsible_party) { ResponsibleParty.new(_id: id, entity_identifier: "parent") }
    before do
      person.responsible_parties << responsible_party
      person.save!
      policy.responsible_party_id = responsible_party._id
    end
    it 'returns the person that has a responsible party that matches the policy responsible party id' do
      expect(policy.responsible_person).to eq person
    end
  end

  describe '#people' do
    let(:lookup_id) { '666' }
    let(:person) { Person.new(name_first: 'Joe', name_last: 'Dirt') }
    let(:enrollee) { build(:enrollee, m_id: lookup_id) }
    let(:member) { build(:member, hbx_member_id: lookup_id) }
    before do
      policy.enrollees = [ enrollee ]
      person.members = [ member ]
      person.save!
    end

    it 'returns people whose members ids match the policy enrollees ids' do
      expect(policy.people).to eq [person]
    end
  end

  describe '#edi_transaction_sets' do
    let(:transation_set_enrollment) { Protocols::X12::TransactionSetEnrollment.new(ts_purpose_code: '00', ts_action_code: '2', ts_reference_number: '1', ts_date: '1', ts_time: '1', ts_id: '1', ts_control_number: '1', ts_implementation_convention_reference: '1', transaction_kind: 'initial_enrollment') }
    context 'transaction set enrollment policy id matches policys id' do
      before do
        transation_set_enrollment.policy_id = policy._id
        transation_set_enrollment.save
      end
      it 'returns the transation set' do
        expect(policy.edi_transaction_sets.to_a).to eq [transation_set_enrollment]
      end
    end

    context 'transaction set enrollment policy id does not matche policys id' do
      before do
        transation_set_enrollment.policy_id = '444'
        transation_set_enrollment.save
      end
      it 'returns the transation set' do
        expect(policy.edi_transaction_sets.to_a).to eq []
      end
    end
  end

  describe '#merge_enrollee' do
    let(:enrollee) { build(:enrollee) }

    context 'no enrollee with member id exists' do
      before { policy.merge_enrollee(enrollee, :stop) }

      context 'action is stop' do
        it 'coverage_status changes to inactive' do
          expect(enrollee.coverage_status).to eq 'inactive'
        end
      end

      it 'adds enrollee to the policy' do
        expect(policy.enrollees).to include(enrollee)
      end
    end

    context 'enrollee with member id exists' do
      before { policy.enrollees << enrollee }
      it 'calls enrollees merge_enrollee' do
        allow(enrollee).to receive(:merge_enrollee)
        policy.merge_enrollee(enrollee, :stop)
        expect(enrollee).to have_received(:merge_enrollee)
      end
    end
  end

  describe '#hios_plan_id' do
    let(:plan) { build(:plan, hbx_plan_id: '666')}
    let(:policy) { build(:policy, plan: plan) }

    it 'returns the policys plan hios id' do
      expect(policy.hios_plan_id).to eq plan.hios_plan_id
    end
  end

  describe '#coverage_type' do
    let(:plan) { build(:plan, coverage_type: 'health') }
    let(:policy) { build(:policy, plan: plan) }

    it 'returns the policys plan coverage type' do
      expect(policy.coverage_type).to eq plan.coverage_type
    end
  end

  describe '#enrollee_for_member_id' do
    context 'given there are no policy enrollees with the member id' do
      it 'returns nil' do
        expect(policy.enrollee_for_member_id('888')).to eq nil
      end
    end

    context 'given a policy enrollee with the member id' do
      let(:member_id) { '666' }
      let(:enrollee) { build(:enrollee, m_id: member_id) }

      before { policy.enrollees = [ enrollee ] }

      it 'returns the enrollee' do
        expect(policy.enrollee_for_member_id(member_id)).to eq enrollee
      end
    end
  end

  describe '.find_all_policies_for_member_id' do
    let(:member_id) { '666' }

    context 'given no policy has enrollees with the member id' do
      it 'returns an empty array' do
        expect(Policy.find_all_policies_for_member_id(member_id)).to eq []
      end
    end

    context 'given policies has enrollees with the member id' do
      let(:enrollee) { build(:enrollee, m_id: member_id) }

      before do
        policy.enrollees = [ enrollee ]
        policy.save!
      end
      it 'returns the policies' do
        expect(Policy.find_all_policies_for_member_id(member_id).to_a).to eq [policy]
      end
    end
  end

  describe '.find_by_sub_and_plan' do
    let(:policy) { create(:policy) }

    it 'finds policies matching subscriber member id and plan id' do
      expect(Policy.find_by_sub_and_plan(policy.enrollees.first.m_id, policy.plan.hios_plan_id)).to eq policy
    end
  end

  describe '.find_by_subkeys' do
    let(:policy) { create(:policy) }

    it 'finds policy by eg_id, carrier_id, and plan_id' do
      expect(Policy.find_by_subkeys(policy.eg_id, policy.carrier_id, policy.plan.hios_plan_id)).to eq policy
    end
  end

  describe '.find_or_update_policy' do
    let(:eg_id) { '1' }
    let(:carrier_id) { '2' }
    let(:plan_id) { '3' }
    let(:plan_hios_id) { "a hios id" }
    let(:plan) { Plan.create!(:name => "test_plan", :hios_plan_id => plan_hios_id, carrier_id: carrier_id, :coverage_type => "health") }
    let(:policy) { Policy.new(enrollment_group_id: eg_id, carrier_id: carrier_id, plan: plan)}
    let(:responsible_party_id) { '1' }
    let(:employer_id) { '2' }
    let(:broker_id) { '3' }
    let(:applied_aptc) { 1.0 }
    let(:tot_res_amt) { 1.0 }
    let(:pre_amt_tot) { 1.0 }
    let(:employer_contribution) { 1.0 }
    let(:carrier_to_bill) { true }

    before do
      policy.responsible_party_id = responsible_party_id
      policy.employer_id = employer_id
      policy.broker_id = broker_id
      policy.applied_aptc = applied_aptc
      policy.tot_res_amt = tot_res_amt
      policy.pre_amt_tot = pre_amt_tot
      policy.employer_contribution = employer_contribution
      policy.carrier_to_bill = carrier_to_bill
    end
    context 'given policy exists' do
      it 'finds and updates the policy' do
        existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan)
        found_policy = Policy.find_or_update_policy(policy)

        expect(found_policy).to eq existing_policy

        expect(found_policy.responsible_party_id).to eq responsible_party_id
        expect(found_policy.employer_id).to eq employer_id
        expect(found_policy.broker_id).to eq broker_id
        expect(found_policy.applied_aptc).to eq applied_aptc
        expect(found_policy.tot_res_amt).to eq tot_res_amt
        expect(found_policy.pre_amt_tot).to eq pre_amt_tot
        expect(found_policy.employer_contribution).to eq employer_contribution
        expect(found_policy.carrier_to_bill).to eq true
      end
    end

    context 'given no policy exists' do
      it 'saves the policy' do
        found_policy = Policy.find_or_update_policy(policy)
        expect(found_policy.persisted?).to eq true
      end
    end

  end

  describe '#check_for_cancel_or_term' do
    let(:subscriber) { Enrollee.new(relationship_status_code: 'self') }
    before { policy.enrollees = [ subscriber ] }

    context 'subscriber is canceled' do
      before { allow(subscriber).to receive(:canceled?).and_return(true) }
      it 'sets policy as canceled' do
        policy.check_for_cancel_or_term
        expect(policy.aasm_state).to eq 'canceled'
      end
    end

    context 'subscriber is terminated' do
      before { allow(subscriber).to receive(:terminated?).and_return(true) }
      it 'sets policy as terminated' do
        policy.check_for_cancel_or_term
        expect(policy.aasm_state).to eq 'terminated'
      end
    end
  end

  describe '.find_covered_in_range' do
    let(:start_date) { Date.new(2014, 1, 1) }
    let(:end_date) { Date.new(2014, 1, 31) }

    let(:enrollee) { build(:subscriber_enrollee, coverage_start: coverage_start, coverage_end: coverage_end) }

    let(:policy) { build(:policy, enrollees: [ enrollee ]) }

    before { policy.save! }
    context 'when subscriber coverage is in range' do
      let(:coverage_start) { start_date.next_day }
      let(:coverage_end) { end_date.prev_day }
      it 'finds the policy' do
        policies = Policy.find_covered_in_range(start_date, end_date)
        expect(policies).to include policy
      end

    end

    context 'when subscriber coverage is out of range' do
      let(:coverage_start) { start_date.prev_year }
      let(:coverage_end) { end_date.prev_year }
      it 'does not find the policys' do
        policies = Policy.find_covered_in_range(start_date, end_date)
        expect(policies).not_to include policy
      end
    end
  end

  describe '#active_enrollees' do
    let(:enrollees) { [ active_enrollee, inactive_enrollee] }

    let(:active_enrollee) { build(:enrollee, coverage_status: 'active') }
    let(:inactive_enrollee) { build(:enrollee, coverage_status: 'inactive') }

    before do
      policy.enrollees = enrollees
      policy.save!
    end

    it 'collects all active enrollees' do
      expect(policy.active_enrollees).to eq [active_enrollee]
    end
  end
end

describe Policy, :dbclean => :after_each do
  let(:eg_id) { "1234" }
  let(:subscriber) { Enrollee.new(:coverage_end => nil, :coverage_start => Date.new(Date.today.year, 1, 1), :rel_code => "self") }
  let(:enrollees) { [subscriber]}
  subject { Policy.new({
    :eg_id => eg_id,
    :enrollees => enrollees
  })}

  context 'builds the correct search hash' do

    let (:search_hash) { Policy.search_hash("1234") }
    let (:params_hash_array) {search_hash.values_at("$or").flatten.flatten}

    it "should be matching any of the keys" do
      expect(search_hash).to include("$or")
    end

    it "should be matching on enrollment group id" do
      expect(params_hash_array.any? { |hash| hash['eg_id'] == /1234/i }).to be_true
    end

    it "should be matching on policy id" do
      expect(params_hash_array.any? { |hash| hash['id'] == "1234" }).to be_true
    end

    it "should be matching on member id's on enrollees" do
      expect(params_hash_array.any? { |hash| hash['enrollees.m_id'] == /1234/i }).to be_true
    end

  end

  context "with an active subscriber" do
    it "should be currently active" do
      expect(subject).to be_currently_active
    end

    context "with a currently active enrollee" do
      let(:enrollee) { Enrollee.new(:m_id => "12354", :coverage_end => nil, :coverage_start => (Date.new(Date.today.year, 1, 1))) }
      let(:enrollees) { [subscriber, enrollee] }

      it "should be currently_active_for enrollee" do
        expect(subject).to be_currently_active_for("12354")
      end

      it 'should be future_active_for enrollee' do
        expect(subject).not_to be_future_active_for(enrollee.m_id)
      end
    end
  end

  context "with an eg_id matching /DC0.{32}/" do
    let(:eg_id) { blarg = "a" * 32; "DC0#{blarg}"}

    it "should not be currently_active" do
      expect(subject).not_to be_currently_active
    end
  end

  context "with a cancelled subscriber" do
    let(:subscriber) { Enrollee.new(:coverage_end => Date.today.prev_year, :coverage_start => Date.today.prev_year, :rel_code => "self") }

    it "should not be currently_active" do
      expect(subject).not_to be_currently_active
    end
  end

  context "with a subscriber with a past termination date" do
    let(:subscriber) { Enrollee.new(:coverage_end => Date.today.prev_year, :coverage_start => Date.today.prev_year.prev_year, :rel_code => "self") }

    it "should not be currently_active" do
      expect(subject).not_to be_currently_active
    end
  end

  context "with a subscriber with a future benefit start date" do
    let(:subscriber) { Enrollee.new(:coverage_end => nil, :coverage_start => Date.today.next_year, :rel_code => "self") }

    it "should not be currently_active" do
      expect(subject).not_to be_currently_active
    end
  end

  context "with a cancelled enrollee" do
    let(:enrollee) { Enrollee.new(:m_id => "12354", :coverage_end => Date.today.prev_year, :coverage_start => Date.today.prev_year) }
    let(:enrollees) { [subscriber, enrollee]}

    it "should not be currently_active_for that enrollee" do
      expect(subject).not_to be_currently_active_for(enrollee.m_id)
    end

    it 'should not be future_active_for enrollee' do
      expect(subject).not_to be_future_active_for(enrollee.m_id)
    end
  end

  context "with an enrollee with a past termination date" do
    let(:enrollee) { Enrollee.new(:m_id => "12354", :coverage_end => Date.today.prev_year, :coverage_start => Date.today.prev_year.prev_year) }
    let(:enrollees) { [subscriber, enrollee]}

    it "should not be currently_active_for enrollee" do
      expect(subject).not_to be_currently_active_for(enrollee.m_id)
    end

    it 'should not be future_active_for enrollee' do
      expect(subject).not_to be_future_active_for(enrollee.m_id)
    end
  end

  context "with an enrollee with a future benefit start date" do
    let(:enrollee) { Enrollee.new(:m_id => "12354", :coverage_end => nil, :coverage_start => Date.today.next_year) }
    let(:enrollees) { [subscriber, enrollee]}

    it "should not be currently_active_for enrollee" do
      expect(subject).not_to be_currently_active_for(enrollee.m_id)
    end

    it 'should be future_active_for enrollee' do
      expect(subject).to be_future_active_for(enrollee.m_id)
    end
  end

end


describe Policy, :dbclean => :after_each do

  let(:aptc_credits) { [aptc_credit1, aptc_credit2] }
  let(:aptc_credit1) { AptcCredit.new(start_on: Date.new(2014, 1, 1), end_on: Date.new(2014, 5, 31), aptc: 100.0, pre_amt_tot: 200.0, tot_res_amt: 100.0) }
  let(:aptc_credit2) { AptcCredit.new(start_on: Date.new(2014, 6, 1), end_on: Date.new(2014, 12, 31), aptc: 125.0, pre_amt_tot: 300.0, tot_res_amt: 175.0) }

  let(:coverage_start) { Date.new(2014, 1, 1) }
  let(:coverage_end) { Date.new(2014, 1, 31) }

  let(:enrollee) { build(:subscriber_enrollee, coverage_start: coverage_start, coverage_end: coverage_end) }
  let(:enrollee2) { build(:subscriber_enrollee, coverage_start: Date.new(2014, 3, 1), coverage_end: Date.new(2014, 3, 31)) }

  subject { Policy.new(applied_aptc: 0.0, pre_amt_tot: 250.0, tot_res_amt: 0.0, aptc_credits: aptc_credits, enrollees: [ enrollee, enrollee2 ]) }

  context ".check_multi_aptc" do
    it "should set premium, responsible amount, aptc from latest aptc credit" do
      subject.check_multi_aptc

      expect(subject.applied_aptc).to eq(100.0)
      expect(subject.pre_amt_tot).to eq(200.0) 
      expect(subject.tot_res_amt).to eq(100.0)
    end
  end

  context ".assistance_effective_date" do
    it "should return latest aptc_record start_on date" do
      expect(subject.assistance_effective_date).to eq aptc_credit2.start_on
    end
  end

  context ".assistance_effective_date with out aptc credits" do
    let(:aptc_credits) { [] }

    it "should return latest date from enrollees coverage_start and coverage_end on policy" do
      expect(subject.assistance_effective_date).to eq enrollee2.coverage_end 
    end
  end

  context ".reported_tot_res_amt_on" do
    let(:date) { Date.new(2014, 2, 1) }

    context 'when aptc credits present' do 
      it 'should return tot_res_amt from aptc credit for matching date' do
        expect(subject.reported_tot_res_amt_on(date)).to eq(100.0)
      end
    end

    context 'when aptc credit not present for given date' do 
      let(:date) { Date.new(2015, 2, 1) }

      it 'should return zero' do
        expect(subject.reported_tot_res_amt_on(date)).to eq(0.0)
      end
    end

    context 'when aptc credit not present' do
      let(:aptc_credits) { [] }
      it 'should return tot_res_amt from policy record' do
        expect(subject.reported_tot_res_amt_on(date)).to eq(0.0) 
      end
    end
  end

  context ".reported_pre_amt_tot_on" do
    let(:date) { Date.new(2014, 6, 1) }

    context 'when aptc credits present' do 
      it 'should return pre_amt_tot from aptc credit' do
        expect(subject.reported_pre_amt_tot_on(date)).to eq(300.0)
      end
    end

    context 'when aptc credit not present for given date' do 
      let(:date) { Date.new(2015, 2, 1) }
      
      it 'should return zero' do
        expect(subject.reported_pre_amt_tot_on(date)).to eq(0.0)
      end
    end

    context 'when aptc credit not present' do
      let(:aptc_credits) { [] }
      it 'should return pre_amt_tot from policy record' do
        expect(subject.reported_pre_amt_tot_on(date)).to eq(250.0) 
      end
    end
  end

  context ".reported_aptc_on" do
    let(:date) { Date.new(2014, 12, 31) }

    context 'when aptc credits present' do 
      it 'should return pre_amt_tot from aptc credit' do
        expect(subject.reported_aptc_on(date)).to eq(125.0)
      end
    end

    context 'when aptc credit not present for given date' do 
      let(:date) { Date.new(2015, 2, 1) }
      
      it 'should return zero' do
        expect(subject.reported_aptc_on(date)).to eq(0.0)
      end
    end

    context 'when aptc credit not present' do
      let(:aptc_credits) { [] }
      it 'should return pre_amt_tot from policy record' do
        expect(subject.reported_aptc_on(date)).to eq(0.0) 
      end
    end
  end

end

describe '.terminate_as_of', :dbclean => :after_each do
  let(:coverage_start) { Date.new(2014, 1, 1) }
  let(:enrollee) { build(:subscriber_enrollee, coverage_start: coverage_start) }
  let(:policy) { build(:policy, enrollees: [ enrollee ]) }
  before { policy.save! }

  context 'when end date after start date' do
    let(:coverage_end) { Date.new(2014, 1, 31) }
    it 'should terminate the policy with given end date' do
      policy.terminate_as_of(coverage_end)
      expect(policy.policy_end).to eq coverage_end
      expect(policy.aasm_state).to eq "terminated"
    end
  end

  context 'when end date before start date' do
    let(:coverage_end) { Date.new(2013, 12, 1) }
    it 'should cancel the policy with start date.' do
      policy.terminate_as_of(coverage_end)
      expect(policy.policy_end).to eq coverage_start
      expect(policy.aasm_state).to eq "canceled"
    end
  end
end

describe '.termination_event_exempt_from_notification?', :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier_id) { '2' }
  let(:plan_id) { '3' }
  let(:plan_hios_id) { "a hios id" }
  let(:plan) { Plan.create!(:name => "test_plan", :hios_plan_id => plan_hios_id, carrier_id: carrier_id, :coverage_type => "health") }
  let(:policy) {Policy.new(enrollment_group_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: 'individual', enrollees: [enrollee1, enrollee2])}
  let(:responsible_party_id) { '1' }
  let(:broker_id) { '3' }
  let(:applied_aptc) { 1.0 }
  let(:tot_res_amt) { 1.0 }
  let(:pre_amt_tot) { 1.0 }
  let!(:child)   {
    person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:primary) {
    person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) {Date.new(2019, 1, 1)}
  let(:coverage_end) {coverage_start.end_of_year}
  let(:enrollee1) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: coverage_start)}
  let(:enrollee2) { Enrollee.new(m_id: child.authority_member.hbx_member_id, rel_code: 'child', coverage_start: coverage_start)}

  before do
    policy.responsible_party_id = responsible_party_id
    policy.broker_id = broker_id
    policy.applied_aptc = applied_aptc
    policy.tot_res_amt = tot_res_amt
    policy.pre_amt_tot = pre_amt_tot
  end

  context 'given no policy exists' do
    it 'saves the policy and do notify' do
      found_policy = Policy.find_or_update_policy(policy)
      expect(found_policy.persisted?).to eq true
      exempt_notification = Policy.termination_event_exempt_from_notification?(nil, found_policy)
      expect(exempt_notification).to eq false
    end
  end

  context "given:
  - policy exists
  - ivl policy
  - health policy
  - existing policy has nil end date(subscriber.coverage_end = nil)
  - finds and updates the policy
  - no change in (term_for_np) NPT flag
  " do

    it "with updated_policy end date to 12/31/PY and don't notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.enrollees.where(rel_code: 'self').first.update_attributes!(coverage_end: coverage_end)
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: coverage_end)
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq true
    end

    it "with only dependent end date to 12/31 and don't notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: coverage_end)
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq true
    end

    it "with only dependent end date from another end_date to 12/31 and do notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      existing_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: Date.new(2019,7,31))
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: coverage_end)
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq false
    end

    it "with only dependent end date not to 12/31 and do notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: nil, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: Date.new(2019,7,31))
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq false
    end
  end

  context "given:
  - policy exists
  - ivl policy
  - health coverage policy
  - existing policy end_date has 12/31/PY
  - finds and updates the policy
  " do

    it "with enrollee end date to 12/31 and don't notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: coverage_end)
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq true
    end

    it "with only dependent end date not to 12/31 and do notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.enrollees.where(rel_code: 'child').first.update_attributes!(coverage_end: Date.new(2019,7,31))
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq false
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq false
    end

    it "with policy end_date to 12/31, npt flag true and do notify" do
      existing_policy = Policy.create!(eg_id: eg_id, carrier_id: carrier_id, plan: plan, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', enrollees: [enrollee1, enrollee2])
      found_policy = Policy.find_or_update_policy(policy)
      found_policy.update_attributes!(term_for_np: true)
      found_policy.enrollees.where(rel_code: 'self').first.update_attributes!(coverage_end: coverage_end)
      exempt_notification = Policy.termination_event_exempt_from_notification?(existing_policy, found_policy)

      expect(found_policy.term_for_np).to eq true
      expect(existing_policy.term_for_np).to eq false
      expect(found_policy).to eq existing_policy
      expect(found_policy.responsible_party_id).to eq responsible_party_id
      expect(found_policy.is_shop?).to eq false
      expect(found_policy.coverage_type).to eq "health"
      expect(exempt_notification).to eq false
    end
  end
end

describe "#cancel_renewal", :dbclean => :after_each do
  let(:eg_id) { '1' }
  let(:carrier) {Carrier.create!(:termination_cancels_renewal => true)}
  let(:plan) { Plan.create!(:name => "test_plan", carrier_id: carrier.id, hios_plan_id: 123 ,:coverage_type => "health", year: Date.today.next_year.year) }
  let(:active_plan) { Plan.create!(:name => "test_plan", carrier_id: carrier.id, hios_plan_id: 123, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let(:catastrophic_active_plan) { Plan.create!(:name => "test_plan", metal_level: 'catastrophic', hios_plan_id: '94506DC0390008', carrier_id: carrier.id, renewal_plan: plan, :coverage_type => "health", year: Date.today.year) }
  let!(:primary) {
    person = FactoryGirl.create :person
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let(:coverage_start) { Date.today.next_year.beginning_of_year }
  let(:enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_month)}
  let(:enrollee2) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.next_year.beginning_of_year, coverage_end: coverage_end)}

  let!(:active_policy) {
    policy = FactoryGirl.create(:policy, enrollment_group_id: eg_id, employer: employer,
                                 hbx_enrollment_ids: ["123"], carrier: carrier,
                                 plan: active_plan,
                                 coverage_start: Date.today.beginning_of_month, kind: kind)
    policy.update_attributes(enrollees: [enrollee], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy = FactoryGirl.create(:policy, enrollment_group_id: eg_id,
                                 employer: employer, carrier: carrier, plan: plan,
                                 coverage_start: Date.today.next_year.beginning_of_year,
                                 coverage_end: coverage_end, kind: kind)
  policy.update_attributes(enrollees: [enrollee2])
  policy.save
  policy
  }

  context "IVL: with renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { nil}
    let(:employer_id) { nil }
    let(:employer) { nil}

    it "should cancel renewal policy on terminating active policy" do
      expect(active_policy.matched_ivl_renewals).to eq [renewal_policy]
      active_policy.terminate_as_of(renewal_policy.coverage_year.end)
      renewal_policy.reload
      expect(renewal_policy.is_shop?).to eq false
      expect(renewal_policy.canceled?).to eq true
    end
  end

  context "IVL with catastrophic plan : with renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { nil}
    let(:employer_id) { nil }
    let(:employer) { nil}
    before do
      active_policy.plan = catastrophic_active_plan
      active_policy.save
    end

    it "should cancel renewal policy on terminating active policy" do
      expect(active_policy.matched_ivl_renewals).to eq [renewal_policy]
      active_policy.terminate_as_of(renewal_policy.coverage_year.end)
      renewal_policy.reload
      expect(renewal_policy.is_shop?).to eq false
      expect(renewal_policy.canceled?).to eq true
    end
  end

  context "IVL: without renewal policy" do
    let(:kind) { 'individual' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year }
    let(:employer_id) { nil }
    let(:employer) { nil}


    it "should return empty array" do
      expect(active_policy.matched_ivl_renewals).to eq []
    end
  end

  context "SHOP: with renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { nil }
    let(:employer) { FactoryGirl.create(:employer)}
    let!(:plan_year) { FactoryGirl.create(:plan_year, employer: employer, start_date: Date.new(Date.today.year, 1, 1), end_date: Date.new(Date.today.year, 12, 31))}
    let(:employer_id) { employer.hbx_id }

    it "should not return renewal policy" do
      expect(renewal_policy.is_shop?).to eq true
      expect(active_policy.matched_ivl_renewals).to eq []
    end
  end

  context "SHOP: without renewal policy" do
    let(:kind) { 'shop' }
    let(:coverage_end) { Date.today.next_year.beginning_of_year  }
    let(:employer) { FactoryGirl.create(:employer)}
    let(:employer_id) { employer.hbx_id }

    it "should return empty array when checked for renewal policy" do
      expect(renewal_policy.is_shop?).to eq true
      expect(active_policy.matched_ivl_renewals).to eq []
    end
  end
end

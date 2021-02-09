require 'rails_helper'
describe Parsers::Edi::IncomingTransaction do
  let(:enrollee) { Enrollee.new(m_id: '1',
                                relationship_status_code: 'self',
                                employment_status_code: 'active',
                                benefit_status_code: 'active',
                                coverage_start: coverage_start,
                                coverage_end: coverage_end ) }
  let(:policy) do
    policy = Policy.new(eg_id: '1', plan_id: '1')
    policy.enrollees << enrollee
    policy.save!
    policy
  end

  let(:coverage_start) { '20140501' }
  let(:coverage_end) { '20140501' }

  let(:policy_loop) { double(id: '4321', action: :stop, coverage_end: coverage_end) }
  let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: '1', carrier_member_id: '1234', policy_loops: [policy_loop], :non_payment_change? => false) }
  let(:etf) { double(people: [person_loop], is_shop?: false) }
  let(:incoming) do
    incoming = Parsers::Edi::IncomingTransaction.new(etf)
    incoming.policy_found(policy)
    incoming
  end

  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }

  before :each do
    allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
    allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.canceled",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
    }, "")
    allow(Observers::PolicyUpdated).to receive(:notify).with(policy)
  end

  it 'imports enrollee carrier member id' do
    incoming.import

    enrollee.reload
    expect(enrollee.c_id).to eq person_loop.carrier_member_id
  end

  it 'imports enrollee carrier policy id' do
    incoming.import

    enrollee.reload
    expect(enrollee.cp_id).to eq policy_loop.id
  end

  context 'when action policy action is stop' do
    it 'sets enrollee coverage status to inactive' do
      incoming.import

      enrollee.reload
      expect(enrollee.coverage_status).to eq 'inactive'
    end

    it 'imports enrollee coverage-end date' do
      incoming.import

      enrollee.reload
      expect(enrollee.coverage_end.strftime("%Y%m%d")).to eq policy_loop.coverage_end
    end

    context 'when coverage start/end are different' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140706' }
      before :each do
        allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
      end

      it "sends the termination notice" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to terminated' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'terminated'
        expect(policy.aasm_state).to eq 'terminated'
      end

      it 'notifies of policy termination' do
        expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
        incoming.import
      end
    end

    context 'when coverage start/end are different, and the reason is non-payment' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140706' }
      let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: '1', carrier_member_id: '1234', policy_loops: [policy_loop], :non_payment_change? => true) }
      before :each do
        allow(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids),
            :qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"
          }
        }, "")
      end

      it "sends the termination notice" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.terminated",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids),
            :qualifying_reason => "urn:openhbx:terms:v1:benefit_maintenance#non_payment"
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to terminated' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'terminated'
        expect(policy.aasm_state).to eq 'terminated'
      end
    end

    context 'when coverage start/end are the same' do
      let(:coverage_start) { '20140501' }
      let(:coverage_end) { '20140501' }

      it "broadcasts the cancel" do
        expect(event_broadcaster).to receive(:broadcast).with({
          :routing_key => "info.events.policy.canceled",
          :headers => {
            :resource_instance_uri => policy.eg_id,
            :event_effective_date => policy.policy_end.strftime("%Y%m%d"),
            :hbx_enrollment_ids => JSON.dump(policy.hbx_enrollment_ids)
          }
        }, "")
        incoming.import
      end

      it 'sets the policy to canceled' do
        incoming.import

        expect(enrollee.policy.aasm_state).to eq 'canceled'
        expect(policy.aasm_state).to eq 'canceled'
      end

      it 'notifies of policy cancelation' do
        expect(Observers::PolicyUpdated).to receive(:notify).with(policy)
        incoming.import
      end
    end
  end
end

describe 'when incoming term/cancel as renewal policy' do
  let(:eg_id) { '1' }
  let(:kind) { 'individual' }
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
  let(:enrollee) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.beginning_of_month, coverage_end:  coverage_end)}
  let(:enrollee2) { Enrollee.new(m_id: primary.authority_member.hbx_member_id, rel_code: 'self', coverage_start: Date.today.next_year.beginning_of_year)}

  let!(:active_policy) {
    policy = FactoryGirl.create(:policy, enrollment_group_id: eg_id,
                                hbx_enrollment_ids: ["123"], carrier: carrier,
                                plan: active_plan,
                                coverage_start: Date.today.beginning_of_month, kind: kind)
    policy.update_attributes(enrollees: [enrollee], hbx_enrollment_ids: ["123"])
    policy.save
    policy
  }
  let!(:renewal_policy) {
    policy = FactoryGirl.create(:policy, enrollment_group_id: eg_id, carrier: carrier, plan: plan,
                                coverage_start: Date.today.next_year.beginning_of_year, kind: kind)
    policy.update_attributes(enrollees: [enrollee2])
    policy.save
    policy
  }

  let(:policy_loop) { double(id: '4321', action: :stop, coverage_end: coverage_end.strftime("%Y%m%d")) }
  let(:person_loop) { instance_double(Parsers::Edi::Etf::PersonLoop, member_id: enrollee.m_id, carrier_member_id: carrier.id, policy_loops: [policy_loop], :non_payment_change? => false) }
  let(:etf) { double(people: [person_loop], is_shop?: false) }
  let(:incoming) do
    incoming = Parsers::Edi::IncomingTransaction.new(etf)
    incoming.policy_found(active_policy)
    incoming
  end
  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }

  context "cancel policy" do
    let!(:coverage_end) { Date.today.beginning_of_month }

    before :each do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast).with({:routing_key => "info.events.policy.canceled",
                                                               :headers => {
                                                                   :resource_instance_uri => active_policy.eg_id,
                                                                   :event_effective_date => active_policy.policy_end.strftime("%Y%m%d"),
                                                                   :hbx_enrollment_ids => JSON.dump(active_policy.hbx_enrollment_ids)
                                                               }
                                                           }, "")
      allow(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
    end

    it "broadcasts the cancel" do
      expect(event_broadcaster).to receive(:broadcast).with({:routing_key => "info.events.policy.canceled",
                                                                :headers => {
                                                                    :resource_instance_uri => active_policy.eg_id,
                                                                    :event_effective_date => active_policy.policy_end.strftime("%Y%m%d"),
                                                                    :hbx_enrollment_ids => JSON.dump(active_policy.hbx_enrollment_ids)
                                                                }
                                                            }, "")
      incoming.import
    end

    it 'sets the policy to canceled' do
      incoming.import
      expect(active_policy.canceled?).to eq true
    end

    it 'notifies of policy cancelation' do
      expect(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
      incoming.import
    end

    it 'should cancel renewal' do
      incoming.import
      expect(active_policy.canceled?).to eq true
      renewal_policy.reload
      expect(renewal_policy.canceled?).to eq true
    end
  end

  context "term policy" do
    let(:coverage_end) {  Date.today.next_year.beginning_of_year - 1.day }

    before :each do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast).with({:routing_key => "info.events.policy.terminated",
                                                               :headers => {
                                                                   :resource_instance_uri => active_policy.eg_id,
                                                                   :event_effective_date => active_policy.policy_end.strftime("%Y%m%d"),
                                                                   :hbx_enrollment_ids => JSON.dump(active_policy.hbx_enrollment_ids)
                                                               }
                                                           }, "")

      allow(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
    end

    it "broadcasts the terminate" do
      expect(event_broadcaster).to receive(:broadcast).with({:routing_key => "info.events.policy.terminated",
                                                                :headers => {
                                                                    :resource_instance_uri => active_policy.eg_id,
                                                                    :event_effective_date => active_policy.policy_end.strftime("%Y%m%d"),
                                                                    :hbx_enrollment_ids => JSON.dump(active_policy.hbx_enrollment_ids)
                                                                }
                                                            }, "")
      incoming.import
    end

    it 'sets the policy to terminated' do
      incoming.import
      expect(active_policy.terminated?).to eq true
    end

    it 'notifies of policy cancelation' do
      expect(Observers::PolicyUpdated).to receive(:notify).with(active_policy)
      incoming.import
    end

    it 'should cancel renewal' do
      incoming.import
      expect(active_policy.terminated?).to eq true
      renewal_policy.reload
      expect(renewal_policy.canceled?).to eq true
    end
  end
end

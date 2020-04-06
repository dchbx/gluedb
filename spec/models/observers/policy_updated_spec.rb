require 'rails_helper'

describe Observers::PolicyUpdated do
  let(:today) { Time.mktime(2025, 1, 1) }
  let(:current_year) { ((today.beginning_of_year)..today.end_of_year) }
  let(:coverage_year_first) { (Time.mktime(2018, 1, 1)..Time.mktime(2018, 12, 31) )}
  let(:coverage_year_too_old) { (Time.mktime(2017, 1, 1)..Time.mktime(2017, 12, 31) )}


  context "given a shop policy" do
    let(:policy) do
      instance_double(
        Policy,
        is_shop?: true,
        kind: 'employer_sponsored'
      )
    end

    it "does nothing" do
      Observers::PolicyUpdated.notify(policy, today)
    end
  end

  context 'given a coverall kind policy' do
    let(:policy) do
      instance_double(
        Policy,
        is_shop?: false,
        kind: 'coverall'
      )
    end

    it "does nothing" do
      Observers::PolicyUpdated.notify(policy, today)
    end
  end

  context "given a dental policy" do
    let(:policy) do
      instance_double(
        Policy,
        is_shop?: true,
        coverage_type: "dental",
        kind: 'employer_sponsored'
      )
    end

    it "does nothing" do
      Observers::PolicyUpdated.notify(policy, today)
    end
  end

  context "given an ivl policy from the current year" do
    let(:policy) do
      instance_double(
        Policy,
        is_shop?: false,
        kind: 'individual',
        coverage_year: current_year,
        coverage_type: "health"
      )
    end

    it "does nothing" do
      Observers::PolicyUpdated.notify(policy, today)
    end
  end

  context "given an ivl policy from before 2018" do
    let(:policy) do
      instance_double(
        Policy,
        is_shop?: false,
        kind: 'individual',
        coverage_year: coverage_year_too_old,
        coverage_type: "health"
      )
    end

    it "does nothing" do
      Observers::PolicyUpdated.notify(policy, today)
    end
  end

  describe 'given IVL policy terminated at 12/31/PY' do
    let!(:child)   {
      person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6)
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let!(:plan) { FactoryGirl.create(:plan) }
    let!(:primary) {
      person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1)
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }
    let(:coverage_start) {Date.new(2019, 1, 1)}
    let(:coverage_end) {coverage_start.end_of_year}
    let(:policy) {
      policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: nil, kind: 'individual'
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'; policy.save
      policy
    }
    let(:policy_id) {policy.id}
    let(:eg_id) {policy.eg_id}
    let(:event_broadcaster) do
      instance_double(Amqp::EventBroadcaster)
    end

    before(:each) do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
    end

    context 'when policy passes check_for_npt_flag_end_date and check_dependent_end_date' do

      it "does nothing" do
        expect(policy.is_shop?).to eq false
        expect(policy.coverage_type).to eq "health"
        policy.terminate_as_of(coverage_end)
        expect(event_broadcaster).not_to receive(:broadcast).with(
          {
            :headers => {
              :policy_id => policy_id,
              :eg_id => eg_id,
            },
            :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
          },
          ""
        )
        Observers::PolicyUpdated.notify(policy, today)
      end
    end

    context 'when depedent has coverage end date other then 12/31/PY' do
      let(:policy2) {
        policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: nil, kind: 'individual'
        policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
        policy.enrollees[1].m_id = child.authority_member.hbx_member_id
        policy.enrollees[1].rel_code ='child'
        policy.enrollees[1].update_attributes!(coverage_end: Time.mktime(2019, 8, 31)); policy.save
        policy
      }
      let(:policy2_id) {policy2.id}
      let(:eg_id2) {policy2.eg_id}

      it "sends the message" do
        expect(policy2.is_shop?).to eq false
        expect(policy2.coverage_type).to eq "health"
        policy2.terminate_as_of(coverage_end)
        policy2.enrollees[1].update_attributes!(coverage_end: Time.mktime(2019, 12, 31))
        expect(event_broadcaster).to receive(:broadcast).with(
          {
            :headers => {
              :policy_id => policy2_id,
              :eg_id => eg_id2,
            },
            :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
          },
          ""
        )
        Observers::PolicyUpdated.notify(policy2, today)
      end
    end

    context 'when term_for_np for current version and previous version is not same' do

      it "sends the message" do
        expect(policy.is_shop?).to eq false
        expect(policy.coverage_type).to eq "health"
        policy.terminate_as_of(coverage_end)
        policy.update_attributes!(term_for_np: true)
        policy.save!
        expect(event_broadcaster).to receive(:broadcast).with(
          {
            :headers => {
              :policy_id => policy_id,
              :eg_id => eg_id,
            },
            :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
          },
          ""
        )
        Observers::PolicyUpdated.notify(policy, today)
      end
    end
  end

  context "given an ivl policy from a previous policy year, after 1/1/2018" do
    let(:policy_id) { "A POLICY ID" }
    let(:eg_id) { "A POLICY ID" }

    let(:event_broadcaster) do
      instance_double(Amqp::EventBroadcaster)
    end

    let(:policy) do
      instance_double(
        Policy,
        :id => policy_id,
        :eg_id => eg_id,
        is_shop?: false,
        kind: 'individual',
        coverage_year: coverage_year_first,
        policy_end: Time.mktime(2018, 11, 30),
        coverage_type: "health"
      )
    end

    before(:each) do
      allow(Amqp::EventBroadcaster).to receive(:with_broadcaster).and_yield(event_broadcaster)
    end

    it "sends the message" do
      expect(event_broadcaster).to receive(:broadcast).with(
        {
          :headers => {
            :policy_id => policy_id,
            :eg_id => eg_id,
          },
          :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
        },
        ""
      )
      Observers::PolicyUpdated.notify(policy, today)
    end
  end
end
require "rails_helper"

describe EnrollmentAction::NotificationExemptionHelper, :dbclean => :after_each do
  subject { Class.new { extend EnrollmentAction::NotificationExemptionHelper } }

  describe "termination_event_exempt_from_notification?" do
    let(:current_year) { ((today.beginning_of_year)..today.end_of_year) }
    let!(:termination_date1) {Date.new(2019, 12, 31) }
    let!(:termination_date2) {"12-31-2019"}
    let!(:termination_date3) {"10/31/2019"}
    let!(:termination_date4) {"10-31-2019"}
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

    context "given a shop policy" do
      let(:policy) do
        instance_double(
          Policy,
          is_shop?: true,
          kind: 'employer_sponsored'
        )
      end

      it "returns false when policy is a shop" do
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date1)).to be_false
      end
    end

    context 'given IVL policy is terminated at 12/31/PY' do
      it "return false when NPT flag change" do
        allow(policy).to receive(:term_for_np).and_return(true)
        expect(policy.is_shop?).to eq false
        expect(policy.coverage_type).to eq "health"
        policy.subscriber.update_attributes!(coverage_end: "12/31/2019")
        policy.update_attributes!(term_for_np: true)
        policy.save!
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date1, true, false)).to be_false
      end

      it "return true when NPT flag won't change" do
        allow(policy).to receive(:term_for_np).and_return(false)
        expect(policy.is_shop?).to eq false
        expect(policy.coverage_type).to eq "health"
        policy.terminate_as_of(coverage_end)
        expect(subject.termination_event_exempt_from_notification?(policy, termination_date1, true, false)).to be_true
      end
    end
  end
end
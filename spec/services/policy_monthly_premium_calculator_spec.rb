require "rails_helper"

describe Services::PolicyMonthlyPremiumCalculator do
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
  let(:calender_year) {Date.today.year}
  let(:coverage_start) {Date.new(calender_year, 1, 1)}
  let(:coverage_end) {coverage_start.end_of_year}
  let(:policy) {
    policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual'
    policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
    policy.enrollees[1].m_id = child.authority_member.hbx_member_id
    policy.enrollees[1].rel_code ='child'; policy.save
    policy
  }
  let(:policy_disposition) {PolicyDisposition.new(policy)}

  subject(:prem_amount_calculator) { Services::PolicyMonthlyPremiumCalculator.new(policy_disposition: policy_disposition, calender_year: calender_year)}

  context 'subscriber and a dependent on a policy with same start date' do
    it 'returns the policy premium amount' do
      expect(prem_amount_calculator.ehb_premium_for(1).round(2)).to eq policy_disposition.as_of(coverage_start).ehb_premium
      expect(prem_amount_calculator.ehb_premium_for(1).round(2)).to eq policy.pre_amt_tot
      expect(prem_amount_calculator.ehb_premium_for(6).round(2)).to eq policy.pre_amt_tot
      expect(prem_amount_calculator.ehb_premium_for(12).round(2)).to eq policy.pre_amt_tot
    end
  end

  context 'A child added on a policy in middle of the month' do
    let(:prorated_amount) {((250.00/31 * 15) + (500.00/31 * 16)).round(2)}

    it 'returns the policy prorated amount in the 3rd month of the calender_year' do
      policy.update_attributes!(pre_amt_tot: "300", tot_res_amt: "300", tot_emp_res_amt: "0", allocated_aptc: "0", elected_aptc: "0", applied_aptc: "0")
      policy.enrollees.where(rel_code: "self").first.update_attributes!(pre_amt: "300")
      policy.enrollees.where(rel_code: "child").first.update_attributes!(pre_amt: "200", coverage_start: Date.new(calender_year, 3, 16) )
      expect(policy.enrollees.count).to eq 2
      expect(policy_disposition.as_of(coverage_start).ehb_premium).to eq 250.00
      expect(prem_amount_calculator.ehb_premium_for(1).round(2)).to eq 250.00
      expect(prem_amount_calculator.ehb_premium_for(2).round(2)).to eq 250.00
      #Prorated amount will be high for 3rd month of the calendar year as a dependent added in middle of the month
      expect(prem_amount_calculator.ehb_premium_for(3).round(2)).to eq prorated_amount
      expect(policy_disposition.as_of(coverage_start + 3.month).ehb_premium).to eq 500.00
      expect(prem_amount_calculator.ehb_premium_for(4).round(2)).to eq 500.00
    end
  end

  context 'A child dropped from the policy in middle of the month' do
    let(:prorated_amount) {((500.00/31 * 15) + (250.00/31 * 16)).round(2)}

    it 'returns the policy prorated amount in the 3rd month of the calender_year' do
      policy.update_attributes!(pre_amt_tot: "300", tot_res_amt: "300", tot_emp_res_amt: "0", allocated_aptc: "0", elected_aptc: "0", applied_aptc: "0")
      policy.enrollees.where(rel_code: "self").first.update_attributes!(pre_amt: "300")
      policy.enrollees.where(rel_code: "child").first.update_attributes!(pre_amt: "200", coverage_end: Date.new(calender_year, 3, 15))
      expect(policy.enrollees.count).to eq 2
      expect((policy_disposition.as_of(coverage_start).ehb_premium).to_f).to eq 500.00
      expect(prem_amount_calculator.ehb_premium_for(1).round(2)).to eq 500.00
      expect(prem_amount_calculator.ehb_premium_for(2).round(2)).to eq 500.00
      #Prorated amount will be less for 3rd month of the calendar year as a dependent dropped in middle of the month
      expect(prem_amount_calculator.ehb_premium_for(3).round(2)).to eq prorated_amount
      expect(policy_disposition.as_of(coverage_start + 3.month).ehb_premium).to eq 250.00
      expect(prem_amount_calculator.ehb_premium_for(4).round(2)).to eq 250.00
    end
  end
end

require "rails_helper"

describe Services::PolicyMonthlyAptcCalculator, :dbclean => :after_each do
  let!(:plan) { FactoryGirl.create(:plan, ehb: '1.0') }
  let!(:primary) {
    person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:child)   {
    person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6)
    person.update(authority_member_id: person.members.first.hbx_member_id)
    person
  }
  let!(:carrier_id) {plan.carrier_id}
  let(:calender_year) {Date.today.year}
  let(:coverage_start) {Date.new(calender_year, 1, 1)}
  let(:coverage_end) {coverage_start.end_of_year}
  let!(:aptc_credits) { [aptc_credit1, aptc_credit2] }
  let!(:aptc_credit1) { AptcCredit.new(start_on: Date.new(calender_year, 1, 1), end_on: Date.new(calender_year, 3, 31), pre_amt_tot:"250.0", tot_res_amt:"50.0", aptc:"100.0") }
  let!(:aptc_credit2) { AptcCredit.new(start_on: Date.new(calender_year, 4, 1), end_on: Date.new(calender_year, 12, 31), pre_amt_tot:"250.0", tot_res_amt:"100.0", aptc:"50.0") }

  let!(:enrollee) { Enrollee.new(rel_code: 'self', coverage_start: coverage_start, coverage_end: coverage_end, pre_amt: '150.0', cp_id: '123456') }
  let!(:enrollee1) { Enrollee.new(rel_code: 'child', coverage_start: coverage_start, coverage_end: coverage_end, pre_amt: '100.0', cp_id: '123456') }
  let!(:policy) {
    policy = Policy.new(eg_id: '123456', pre_amt_tot: "250.0", tot_res_amt: "100.0", tot_emp_res_amt: "0.0", allocated_aptc: "0.0", elected_aptc: "0.0", applied_aptc: '50.0', aptc_credits: aptc_credits, enrollees: [enrollee, enrollee1], plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', carrier_id: carrier_id)
    policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
    policy.enrollees[1].m_id = child.authority_member.hbx_member_id
    policy.enrollees[1].rel_code ='child'
    policy.save
    policy
  }
  let(:policy_disposition) {PolicyDisposition.new(policy)}
  subject(:monthly_aptc_calculator) { Services::PolicyMonthlyAptcCalculator.new(policy_disposition: policy_disposition, calender_year: calender_year)}

  context 'subscriber and a dependent on a policy with same start date and with same aptc amounts' do
    it 'returns the policy applied_aptc' do
      expect(monthly_aptc_calculator.max_aptc_amount_for(1).round(2)).to eq policy_disposition.as_of(coverage_start).applied_aptc
      expect(monthly_aptc_calculator.max_aptc_amount_for(4).round(2)).to eq policy.applied_aptc
    end
  end

  context 'A child added on a policy in middle of the month' do
    let!(:enrollee2) { Enrollee.new(rel_code: 'child', coverage_start: Date.new(calender_year,3,16), coverage_end: coverage_end, pre_amt: '100.0', cp_id: '123456') }
    let!(:policy) {
      policy = Policy.new(eg_id: '123456', pre_amt_tot: "250.0", tot_res_amt: "100.0", tot_emp_res_amt: "0.0", allocated_aptc: "0.0", elected_aptc: "0.0", applied_aptc: '50.0', aptc_credits: aptc_credits, enrollees: [enrollee, enrollee2], plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', carrier_id: carrier_id)
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'
      policy.save
      policy
    }
    let(:aptc_prorated_amount) {((100.00/31 * 15) + (50.00/31 * 16)).round(2)}

    it 'return applied_aptc amount as Aptc dates are not changed' do
      expect(policy.enrollees.count).to eq 2
      expect(policy_disposition.as_of(coverage_start).applied_aptc).to eq 100.00
      expect(policy_disposition.as_of(Date.new(calender_year, 4, 1)).applied_aptc).to eq 50.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(1).round(2)).to eq 100.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(4).round(2)).to eq 50.00
    end

    it 'returns the aptc prorated amount in the 3rd month of the calender_year' do
      policy.aptc_credits.where(start_on: coverage_start).first.update_attributes!(end_on: Date.new(calender_year, 3, 15))
      policy.aptc_credits.where(end_on: coverage_end).first.update_attributes!(start_on: Date.new(calender_year, 3, 16))
      expect(policy.enrollees.count).to eq 2
      expect(policy_disposition.as_of(coverage_start).applied_aptc).to eq 100.00
      expect(policy_disposition.as_of(Date.new(calender_year, 4, 1)).applied_aptc).to eq 50.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(1).round(2)).to eq 100.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(3).round(2)).to eq aptc_prorated_amount
      expect(monthly_aptc_calculator.max_aptc_amount_for(4).round(2)).to eq 50.00
    end
  end

  context 'A child dropped on a policy in middle of the month' do
    let(:prorated_amount) {((250.00/31 * 15) + (500.00/31 * 16)).round(2)}
    let!(:enrollee3) { Enrollee.new(rel_code: 'child', coverage_start: coverage_start, coverage_end: Date.new(calender_year,3,15), pre_amt: '100.0', cp_id: '123456') }
    let!(:aptc_credits1) { [aptc_credit3, aptc_credit4] }
    let!(:aptc_credit3) { AptcCredit.new(start_on: Date.new(calender_year, 1, 1), end_on: Date.new(calender_year, 3, 15), pre_amt_tot:"250.0", tot_res_amt:"100.0", aptc:"50.0") }
    let!(:aptc_credit4) { AptcCredit.new(start_on: Date.new(calender_year, 3, 16), end_on: Date.new(calender_year, 12, 31), pre_amt_tot:"250.0", tot_res_amt:"50.0", aptc:"100.0") }
    let!(:policy) {
      policy = Policy.new(eg_id: '123456', pre_amt_tot: "250.0", tot_res_amt: "100.0", tot_emp_res_amt: "0.0", allocated_aptc: "0.0", elected_aptc: "0.0", applied_aptc: '50.0', aptc_credits: aptc_credits1, enrollees: [enrollee, enrollee3], plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end, kind: 'individual', carrier_id: carrier_id)
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'
      policy.save
      policy
    }
    let(:aptc_prorated_amount) {((50.00/31 * 15) + (100.00/31 * 16)).round(2)}

    it 'return applied_aptc amount as Aptc dates are not changed' do
      expect(policy.enrollees.count).to eq 2
      expect(policy_disposition.as_of(coverage_start).applied_aptc).to eq 50.00
      expect(policy_disposition.as_of(Date.new(calender_year, 4, 1)).applied_aptc).to eq 100.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(1).round(2)).to eq 50.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(4).round(2)).to eq 100.00
    end

    it 'returns the aptc prorated amount in the 3rd month of the calender_year' do
      policy.aptc_credits.where(start_on: coverage_start).first.update_attributes!(end_on: Date.new(calender_year, 3, 15))
      policy.aptc_credits.where(end_on: coverage_end).first.update_attributes!(start_on: Date.new(calender_year, 3, 16))
      expect(policy.enrollees.count).to eq 2
      expect(policy_disposition.as_of(coverage_start).applied_aptc).to eq 50.00
      expect(policy_disposition.as_of(Date.new(calender_year, 4, 1)).applied_aptc).to eq 100.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(1).round(2)).to eq 50.00
      expect(monthly_aptc_calculator.max_aptc_amount_for(3).round(2)).to eq aptc_prorated_amount
      expect(monthly_aptc_calculator.max_aptc_amount_for(4).round(2)).to eq 100.00
    end
  end
end

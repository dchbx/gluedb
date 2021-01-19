require 'rails_helper'

module Generators::Reports
  describe SbmiPolicyBuilder, :dbclean => :after_each do

    let(:plan)           { FactoryGirl.create(:plan) }
    let(:calender_year)  { 2018 }
    let(:coverage_start) { Date.new(calender_year, 1, 1) }
    let(:coverage_end)   { Date.new(calender_year, 6, 30) }

    let(:primary) {
      person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1), name_first: "John", name_last: "Roberts"
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }

    let!(:child)   { 
      person = FactoryGirl.create :person, dob: Date.new(1998, 9, 6), name_first: "Adam", name_last: "Roberts"
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }

    let(:policy) {
      policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: coverage_start, coverage_end: coverage_end
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'; policy.save
      policy
    }

    subject { Generators::Reports::SbmiPolicyBuilder.new(policy) }

    it 'should build sbmi policy struct' do
      subject.process
      sbmi_policy = subject.sbmi_policy
      
      expect(sbmi_policy.coverage_start).to eq coverage_start.strftime('%Y-%m-%d')
      expect(sbmi_policy.coverage_end).to eq coverage_end.strftime('%Y-%m-%d')
      expect(sbmi_policy.coverage_household.size).to eq 2
      expect(sbmi_policy.coverage_household).to include(a_kind_of(PdfTemplates::SbmiEnrollee))
      expect(sbmi_policy.financial_loops).to be_present
      expect(sbmi_policy.financial_loops).to include(a_kind_of(PdfTemplates::FinancialInformation))
    end
  end
end
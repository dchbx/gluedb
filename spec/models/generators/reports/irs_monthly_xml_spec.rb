require 'rails_helper'

module Generators::Reports
  describe IrsMonthlyXml, :dbclean => :after_each do

    let(:slcsp_hios)   { {:slcsp => "94506DC0390014-01"} }
    let!(:plan)        { FactoryGirl.create(:plan) }
    let!(:silver_plan) { FactoryGirl.create(:plan, hios_plan_id: slcsp_hios[:slcsp]) }
    let(:calender_year) { 2018 }
    let(:irs_settings) { 
      settings = YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access 
      settings['tax_document'].merge!({calender_year => slcsp_hios })
      settings
    }
    
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

    let(:primary_family_member) {
      family_member = FamilyMember.new(is_primary_applicant: true, is_consent_applicant: true)
      family_member.person = primary
      family_member
    }

    let(:child_family_member) {
      family_member = FamilyMember.new
      family_member.person = child
      family_member 
    }

    let(:coverage_end) { Date.new(calender_year, 6, 30) }

    let(:policy) {
      policy = FactoryGirl.create :policy, plan_id: plan.id, coverage_start: Date.new(calender_year, 1, 1), coverage_end: coverage_end
      policy.enrollees[0].m_id = primary.authority_member.hbx_member_id
      policy.enrollees[1].m_id = child.authority_member.hbx_member_id
      policy.enrollees[1].rel_code ='child'; policy.save
      policy
    }

    let!(:family) {
      family = FactoryGirl.build(:family)
      family.family_members = [primary_family_member, child_family_member]
      family.irs_groups.build
      household = family.households.new(effective_start_date: Date.today.beginning_of_year)
      household.hbx_enrollments.build(policy_id: policy.id, kind: 'unassisted_qhp'); family.save
      family
    }

    let(:file) { Rails.root.join("#{family.e_case_id}_#{irs_group.identification_num}.xml") }

    let(:monthly_xsd) {
      Nokogiri::XML::Schema(File.open("#{Rails.root.join('spec', 'support')}/xsds/h36/MSG/HHS-IRS-MonthlyExchangePeriodicDataMessage-1.0.xsd")) # IRS 2016
    }

    let(:irs_group) { 
      group_builder = Generators::Reports::IrsGroupBuilder.new(family)
      group_builder.calender_year = calender_year
      group_builder.npt_policies  = []
      group_builder.settings = irs_settings
      group_builder.process
      group_builder.irs_group
    }

    subject { 
      xml = Generators::Reports::IrsMonthlyXml.new(irs_group, family.e_case_id)
      xml.folder_path = Rails.root.to_s
      xml.serialize
    }

    before do
      irs_group.insurance_policies.each do |insurance_policy|
        allow(insurance_policy).to receive(:issuer_fein).and_return("637412315")
      end
    end

    it 'should build households and tax households' do
      expect(irs_group.households).to be_present
      expect(irs_group.households.first.tax_households).to be_present
      expect(irs_group.identification_num).to be_present
    end

    it 'should build insurance policies ' do
      expect(irs_group.insurance_policies).to be_present
      expect(irs_group.insurance_policies.first.monthly_premiums.count).to eq coverage_end.month
    end

    it 'should generate monthly xml' do
      subject
      expect(File.exists?(file)).to be_truthy
      File.delete file
    end

    it 'should generate valid monthly h36' do
      subject
      doc = Nokogiri::XML(File.open(file))
      expect(monthly_xsd.valid?(doc)).to be_truthy
      File.delete file
    end
  end
end
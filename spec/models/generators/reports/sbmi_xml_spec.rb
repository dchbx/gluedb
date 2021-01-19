require 'rails_helper'

module Generators::Reports
  describe SbmiXml, :dbclean => :after_each do

    let(:plan)           { FactoryGirl.create(:plan) }
    let(:calender_year)  { 2018 }
    let(:coverage_start) { Date.new(calender_year, 1, 1) }
    let(:coverage_end)   { Date.new(calender_year, 6, 30) }

    let(:primary) {
      person = FactoryGirl.create :person, dob: Date.new(1970, 5, 1), name_first: "John", name_last: "Roberts"
      person.update(authority_member_id: person.members.first.hbx_member_id)
      person
    }

    let(:child)   { 
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

    let(:sbmi_policy_builder) { 
      policy_builder = Generators::Reports::SbmiPolicyBuilder.new(policy)
      policy_builder.process
      policy_builder
    }

    let(:file) { Rails.root.join("#{sbmi_policy_builder.sbmi_policy.record_control_number}.xml") }

    subject { 
      sbmi_xml = Generators::Reports::SbmiXml.new
      sbmi_xml.sbmi_policy = sbmi_policy_builder.sbmi_policy
      sbmi_xml.folder_path = Rails.root.to_s
      sbmi_xml.serialize
    }

    it 'should generate sbmi xml' do
      subject
      
      expect(File.exists?(file)).to be_truthy
      File.delete file
    end


    it 'should build sbmi xml with member and financial information' do
      subject

      doc = Nokogiri::XML(File.open(file))
      expect(doc.at('MemberInformation')).to be_present
      expect(doc.at('FinancialInformation')).to be_present

      File.delete file
    end
  end
end
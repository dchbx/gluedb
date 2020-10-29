require 'rails_helper'

module Generators::Reports
  describe IrsInputBuilder do
    subject { IrsInputBuilder.new(policy) }

    let(:policy)     { double(id: 24, subscriber: subscriber, enrollees: [subscriber, dependent1, dependent2], policy_start: policy_start, policy_end: policy_end, plan: plan, eg_id: 212131212, applied_aptc: 0, responsible_party_id: nil, coverage_period: (policy_start..policy_end), aptc_credits: aptc_credits) }
    let(:plan)       { double(carrier: carrier, hios_plan_id: '123121') }
    let(:carrier)    { double(name: 'Care First')}
    let(:policy_start) { Date.new(2016, 1, 1) }
    let(:policy_end)   { Date.new(2016, 12, 31) } 
    let(:subscriber) { double(person: person, relationship_status_code: 'Self', coverage_start: policy_start, coverage_end: policy_end, m_id: authority_member.id) }
    let(:dependent1) { double(person: person, relationship_status_code: 'Spouse', coverage_start: policy_start, coverage_end: policy_end) }
    let(:dependent2) { double(person: person, relationship_status_code: 'Child', coverage_start: policy_start, coverage_end: policy_end) }

    let(:person)           { double(full_name: 'Ann B Mcc', addresses: [address], authority_member: authority_member, name_first: 'Ann', name_middle: 'B', name_last: 'Mcc', name_sfx: '', mailing_address: address) }
    let(:authority_member) { double(ssn: '342321212', dob: (Date.today - 20.years), id: '252342323') }
    let(:address)          { double(address_1: 'Wilson Building', address_2: 'Suite 100', city: 'Washington DC', state: 'DC', zip: '20002') }

    let(:address_hash) { 
      { 
        street_1: 'Wilson Building', 
        street_2: 'Suite 100', 
        city: 'Washington DC', 
        state: 'DC', 
        zip: '20002'
      } 
    }
    let!(:aptc_credits) { [aptc_credit1, aptc_credit2] }
    let!(:aptc_credit1) { AptcCredit.new(start_on: Date.new(2016, 1, 1), end_on: Date.new(2016, 3, 31), pre_amt_tot:"250.0", tot_res_amt:"50.0", aptc:"100.0") }
    let!(:aptc_credit2) { AptcCredit.new(start_on: Date.new(2016, 4, 1), end_on: Date.new(2016, 12, 31), pre_amt_tot:"250.0", tot_res_amt:"100.0", aptc:"50.0") }
    let(:mock_disposition) { double(enrollees: policy.enrollees, start_date: policy_start, end_date: policy_end ) }
    let(:mock_policy)      { double(pre_amt_tot: 0.0, ehb_premium: 100.17, applied_aptc: 55.45) }
    let(:carrier_hash)     { {'221212312' => 'Carefirst'} }
    let(:settings)         { YAML.load(File.read("#{Rails.root}/config/irs_settings.yml")).with_indifferent_access }

    before(:each) do
      allow(PolicyDisposition).to receive(:new).with(policy).and_return(mock_disposition)
      allow(policy).to receive(:changes_over_time?).and_return(false)
      allow(policy).to receive(:spouse).and_return(dependent1)
      allow(policy).to receive(:carrier_id).and_return('221212312')
      allow(policy).to receive(:canceled?).and_return(false)

      allow(subscriber).to receive(:canceled?).and_return(false)
      allow(dependent1).to receive(:canceled?).and_return(false)
      allow(dependent2).to receive(:canceled?).and_return(false)
      allow(address).to receive(:to_hash).and_return(address_hash)
      allow(mock_disposition).to receive(:policy).and_return(policy)
      allow(mock_disposition).to receive(:as_of).and_return(mock_policy)

      subject.carrier_hash = carrier_hash
      subject.settings = settings
    end

    it 'should append recipient address' do
      subject.process

      expect(subject.notice.recipient_address).to be_kind_of(PdfTemplates::NoticeAddress)
      expect(subject.notice.recipient_address.street_1).to eq(address.address_1)
      expect(subject.notice.recipient_address.street_2).to eq(address.address_2)
      expect(subject.notice.recipient_address.city).to eq(address.city)
      expect(subject.notice.recipient_address.state).to eq(address.state)
      expect(subject.notice.recipient_address.zip).to eq(address.zip)
    end

    it 'should append household' do
      subject.process

      expect(subject.notice.recipient).to be_kind_of(PdfTemplates::Enrollee)
      expect(subject.notice.spouse).to be_kind_of(PdfTemplates::Enrollee)
    end

    it 'should append monthly premiums' do
      subject.process

      expect(subject.notice.monthly_premiums.count).to eq(12)
      expect(subject.notice.monthly_premiums.first).to be_kind_of(PdfTemplates::MonthlyPremium)
    end

    context "when coverage end date is middle of the year" do 
      let(:policy_end) { Date.new(2016, 7, 31) }

      it 'should calculate premiums only for the covered months' do
        subject.process

        expect(subject.notice.monthly_premiums.count).to eq(7)
        expect(subject.notice.monthly_premiums.map(&:serial).sort).to eq([1,2,3,4,5,6,7])
      end
    end

    context "when both start, end dates are in the middle of the year" do 
      let(:policy_start) { Date.new(2016, 5, 01) }
      let(:policy_end) { Date.new(2016, 9, 30) }

      it 'should append premiums only for covered period' do
        subject.process

        expect(subject.notice.monthly_premiums.count).to eq(5)
        expect(subject.notice.monthly_premiums.map(&:serial).sort).to eq([5,6,7,8,9])
      end
    end
  end
end

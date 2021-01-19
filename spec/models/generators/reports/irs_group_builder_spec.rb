require 'rails_helper'

module Generators::Reports
  describe IrsGroupBuilder do

    subject { IrsGroupBuilder.new(family) }

    let(:months) { 3 }
    let(:calender_month) { 1 }
    let(:family) { double(households: households) }
    let(:households) { [household1, household2] }
    let(:household1) { double(tax_households: [double, double]) }
    let(:household2) { double }

    # let(:mock_household) { PdfTemplates::Household.new }
    # let(:mock_taxhousehold) { PdfTemplates::TaxHousehold.new }
    # let(:mock_household_coverage) { PdfTemplates::TaxHouseholdCoverage.new }
    # let(:mock_member) { double }
    # let(:mock_tax_member) { PdfTemplates::Enrollee.new }
    # let(:tax_household) { double(primary: double, spouse: double, dependents: []) }

    # context 'tax household' do
    #   it 'should have same number of coverages as number of months' do
    #     allow(subject).to receive(:build_household_coverage).and_return(mock_household_coverage)

    #     household = subject.build_taxhousehold(tax_household)
    #     expect(household.tax_household_coverages.count).to eq(months)
    #   end
    # end

    # context 'tax household coverage' do 
    #   it 'should build coverage for the calender month' do 
    #     allow(subject).to receive(:build_tax_member).and_return(mock_tax_member)
    #     allow(tax_household).to receive(:coverage_as_of).and_return( [])

    #     coverage = subject.build_household_coverage(tax_household, calender_month)
    #     expect(coverage).to be_kind_of(PdfTemplates::TaxHouseholdCoverage)
    #     expect(coverage.calender_month).to eq(calender_month)
    #   end
    # end

    context 'tax household member builder' do
      let(:household_member) { double(family_member: family_member, class: 'TaxHouseholdMember')}
      let(:family_member) { double(person: person)}
      let(:person) { double(authority_member: nil) }

      context 'when household member passed is nil' do 
        let(:household_member) { nil }

        it 'should return nil' do 
          tax_member = subject.build_tax_member(household_member)
          expect(tax_member).to be_nil 
        end
      end 

      context 'when household member passed has no authority member set' do 

        it 'should return nil' do 
          tax_member = subject.build_tax_member(household_member)
          expect(tax_member).to be_nil 
        end
      end

      context 'when household member passed is a valid member' do
        let(:person) { double(authority_member: member, full_name: 'mark', name_first: 'mark', name_middle: '', name_last: '', name_sfx: '')}
        let(:member) { double(ssn: '3742322320', dob: Date.parse('12/19/1983') )}

        it 'should return enrollee template object' do
          allow(subject).to receive(:build_address).and_return(nil)

          tax_member = subject.build_tax_member(household_member)
          expect(tax_member).to be_kind_of(PdfTemplates::Enrollee)     
        end
      end
    end
  end
end
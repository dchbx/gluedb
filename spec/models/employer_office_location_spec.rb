require 'rails_helper'
describe EmployerOfficeLocation do


  describe "with a name of Location 1" do
    it "should have a valid office location" do
      subject.name = "Location 1"
      subject.valid?
      expect(subject).not_to have_at_least(1).errors_on(:name)
    end
  end

  describe 'office location' do
    let(:location) { build(:employer_office_location) }

    ['location 1', 'location 2', 'location 3'].each do |name|
      context('when ' + name) do
        before { location.name = name}
        it 'is valid' do
          expect(location).to be_valid
        end
      end
    end
  end

end

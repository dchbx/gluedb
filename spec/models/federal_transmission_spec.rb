require "rails_helper"

describe FederalTransmission, type: :model, :dbclean => :after_each do
  
  context "A new model instance" do
    let(:policy) {FactoryGirl.create(:policy)} 
    let(:params) {{report_type: "ORIGINAL", batch_id: "1241241", content_file: "00001", record_sequence_number: "010101"}}

    it "should not be valid" do
      expect {described_class.create!}.to raise_error(Mongoid::Errors::Validations)
    end

    it "should create federal_transmissions object" do
      policy.federal_transmissions.create!(params)
      expect(policy.federal_transmissions.count).to eq 1
    end
  end

  context "has to check for fields types" do
    it {
      is_expected.to have_field(:report_type).of_type(String).with_default_value_of("ORIGINAL")
      is_expected.to have_field(:batch_id).of_type(String)
      is_expected.to have_field(:content_file).of_type(String)
      is_expected.to have_field(:record_sequence_number).of_type(String)
    }
  end

  context "has to check for relationships" do
    it {
      is_expected.to be_embedded_in(:policy)
    }
  end

  context "has to check for validators" do
    it {
      is_expected.to validate_presence_of(:report_type)
      is_expected.to validate_presence_of(:batch_id)
      is_expected.to validate_presence_of(:content_file)
      is_expected.to validate_presence_of(:record_sequence_number)
    }
  end
end
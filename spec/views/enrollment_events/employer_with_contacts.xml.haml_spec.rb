require "rails_helper"
require File.join(Rails.root, "spec", "support", "acapi_vocabulary_spec_helpers")

describe "enrollment_events/_employer_with_contacts.xml.haml" do
  include AcapiVocabularySpecHelpers

  before :all do
    download_vocabularies
  end

  let(:address) do 
    instance_double Address, 
      address_type:"mailing",
      address_1:"14400 Harvard",
      address_2:"Apt 3",
      address_3: "Ste. 200",
      city:"Winters",
      state:"CA",
      county:"Yolo",
      zip:"95694" 
  end

  let(:addresses) do 
    [address]
  end
  let(:phone) do 
    instance_double Phone,
      phone_type:"mobile",
      phone_number:"5102222222",
      extension:"123",
      primary: nil,
      country_code:"1",
      area_code:"123",
      full_phone_number:"123-456-5678"
  end

  let(:phones) do 
    [phone]
  end

  let(:emails) do 
    [email]
  end

  let(:email) do 
    instance_double Email,
      email_type:"home",
      email_address:"tim@tim.com"
  end

  let (:employer_contact) do 
    instance_double EmployerContact,
      name_prefix:"Mr.",
      first_name:"Joe", 
      middle_name:"louis",
      last_name:"smith", 
      name_suffix:"Sr.",
      job_title:"Director",
      department:"HR" 
  end

  let (:employer_office_location) do 
    instance_double(EmployerOfficeLocation)
  end

  let(:employer) do
    instance_double Employer,
      hbx_id: '1',
      name:"Jim",
      dba: "dba",
      fein: "12345",
      employer_contacts: [employer_contact],
      employer_office_locations: [employer_office_location]
  end

  before do
    allow(employer_contact).to receive(:id).and_return("1")
    allow(employer_contact).to receive(:addresses).and_return(addresses)
    allow(employer_contact).to receive(:phones).and_return(phones)
    allow(employer_contact).to receive(:emails).and_return(emails)
    

  end

  subject do
    ApplicationController.new.render_to_string(
      :layout => nil,
      :partial => "enrollment_events/employer_with_contacts",
      :object => employer,
      :format => :xml
    )
  end

  it "should be schema valid" do
    expect(validate_with_schema(Nokogiri::XML(subject))).to eq([])
  end

end

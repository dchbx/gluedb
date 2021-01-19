require "rails_helper"
require File.join(Rails.root, "spec", "support", "acapi_vocabulary_spec_helpers")

describe "enrollment_events/_employer_with_office_locations.xml.haml" do
  include AcapiVocabularySpecHelpers

  before :all do
    download_vocabularies
  end

  let(:address) do 
    instance_double Address, 
      address_type:"mailing", 
      location_state_code:"CA",
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

  let(:employer_office_location) do 
    instance_double EmployerOfficeLocation,
      name:"place",
      is_primary: nil,
      address: address,
      phone: phone
  end

  let (:employer_office_locations) do 
    [employer_office_location]
  end

  let(:employer) do
    instance_double Employer,
      hbx_id: '1',
      name:"Jim",
      dba: "dba",
      fein: "12345",
      employer_office_locations: employer_office_locations
  end

  before do
    allow(employer_office_location).to receive(:phone).and_return(phone)
    allow(employer_office_location).to receive(:address).and_return(address)
  end

  subject do
      rendered_xml = ApplicationController.new.render_to_string(
        :layout => nil,
        :partial => "enrollment_events/employer_with_office_locations",
        :object => employer,
        :format => :xml
      )
      "<organization xmlns='http://openhbx.org/api/terms/1.0'>
              <id>
                <id></id> 
              </id>  
              <name>This one place</name>
              #{rendered_xml}
              <website></website>
              <contacts>
                <contact>
                  <id>
                    <id>123344</id>
                  </id>
                  <person_name>
                    <person_surname>Smith</person_surname>
                    <person_given_name>Dan</person_given_name>
                    <person_middle_name>l</person_middle_name>
                    <person_name_suffix_text>Sr.</person_name_suffix_text>
                    <person_alternate_name>Sr.</person_alternate_name>
                  </person_name>
                  <job_title>rector</job_title>
                  <department>hr</department>
                  <addresses>
                    <address>
                    <type>urn:openhbx:terms:v1:address_type#home</type>
                    <address_line_1>12 Downing</address_line_1>
                    <address_line_2>23 Taft </address_line_2>
                    <location_city_name>Washington </location_city_name>
                    <location_state_code>DC</location_state_code>
                    <postal_code>12344</postal_code>
                    </address>
                  </addresses>
                  <phones>
                    <phone>
                    <type>urn:openhbx:terms:v1:phone_type#home</type>
                    <full_phone_number>123322222</full_phone_number>
                    <is_preferred>true</is_preferred>
                    </phone>
                  </phones>
                  <created_at>#{DateTime.new(2001,2,3,4,5,6)}</created_at>
                  <modified_at>#{DateTime.new(2001,2,3,4,5,6)}</modified_at>
                  <version>1</version>
                </contact>
              </contacts>
              <is_active>true</is_active>
            </organization>"
  end

  it "should be schema valid" do
    expect(validate_with_schema(Nokogiri::XML(subject))).to eq([])
  end

end

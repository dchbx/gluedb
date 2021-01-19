require "rails_helper"
require File.join(Rails.root, "spec", "support", "acapi_vocabulary_spec_helpers")

describe "enrollment_events/_policy.xml" do
  include AcapiVocabularySpecHelpers

  before :all do
    download_vocabularies
  end

  let(:address) do 
    instance_double Address,
      address_type:"urn:openhbx:terms:v1:address_type#mailing",
      state:"CA",
      address_1:"14400 Harvard",
      address_2:"Apt 3",
      address_3: "Ste. 200",
      city:"Winters",
      county:"Yolo",
      zip:"95694"
  end

  let(:addresses) do 
    [address]
  end

  let(:phone) do 
    instance_double Phone,
      phone_type:"urn:openhbx:terms:v1:phone_type#mobile",
      phone_number:"5102222222",
      extension:"123",
      primary: true,
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
     email_type:"urn:openhbx:terms:v1:email_type#home",
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
      department:"HR",
      emails: emails,
      phones: phones,
      addresses: addresses
  end

  let(:employer_office_location) do
      instance_double EmployerOfficeLocation,
        name:"Primary",
        is_primary:true,
        address: address,
        phone: phone
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

  let(:broker) do
    instance_double Broker,
      npn: 'npn',
      full_name: 'Full Name',
      is_active: true
  end

  let(:carrier) do
    instance_double Carrier,
      name: 'Carrier',
      hbx_carrier_id: 'hbx_carrier_id',
      id: 'sd8f7s9d8f7'
  end

  let(:plan) do
    instance_double Plan,
      hios_plan_id: 'hios_plan_id',
      carrier: carrier,
      name: "The Plan",
      year: Date.today.year,
      coverage_type: 'health',
      metal_level: 'Gold',
      ehb: BigDecimal.new("0.0"),
      id: 'a12db3',
      carrier_id: carrier.id
  end


  let(:shop_policy) do
    instance_double Policy,
      eg_id: 'the-eg-id',
      broker: broker,
      subscriber: subscriber,
      is_cobra?: false,
      composite_rating_tier: "23",
      has_responsible_person?: false,
      plan: plan,
      carrier_specific_plan_id: 'carrier_specific_plan_id',
      is_shop?: true,
      employer: employer,
      applied_aptc: BigDecimal.new("0.0"),
      assistance_effective_date: Date.today + 1.day,
      pre_amt_tot: BigDecimal.new("899.99"),
      tot_res_amt: BigDecimal.new("899.99"),
      tot_emp_res_amt:BigDecimal.new("899.99"),
      rating_area: 'rating_area',
      created_at: Time.now - 1.week,
      updated_at: nil
end


  let(:subscriber_person) do
    instance_double Person,
      authority_member: instance_double(Member,
        hbx_member_id: 'hbx_member_id',
        ssn: '222-22-2222',
        dob: Date.new(1981, 9, 22),
        gender: 'male'),
      name_first: 'John',
      name_last: 'Jacobjingheimerschmidt',
      name_pfx: nil,
      name_sfx: nil,
      name_middle: nil,
      addresses: [],
      emails: [],
      phones: []
  end

  let(:subscriber) do
    instance_double Enrollee,
      person: subscriber_person,
      subscriber?: true,
      pre_amt: BigDecimal.new("899.99"),
      coverage_start: Date.today + 1.day,
      coverage_end: Time.now.end_of_year.to_date,
      cp_id: 'carrier_policy_id',
      c_id: 'carrier_member_id'
  end

  let(:policy) do
    instance_double Policy,
      eg_id: 'the-eg-id',
      broker: broker,
      subscriber: subscriber,
      has_responsible_person?: false,
      plan: plan,
      carrier_specific_plan_id: 'carrier_specific_plan_id',
      is_shop?: false,
      applied_aptc: BigDecimal.new("0.0"),
      assistance_effective_date: Date.today + 1.day,
      pre_amt_tot: BigDecimal.new("899.99"),
      tot_res_amt: BigDecimal.new("899.99"),
      rating_area: 'rating_area',
      created_at: Time.now - 1.week,
      updated_at: nil
  end

  let(:life_partner_person) do
    instance_double Person,
      authority_member: instance_double(Member,
        hbx_member_id: 'hbx_member_id',
        ssn: '222-22-2223',
        dob: Date.new(1981, 9, 22),
        gender: 'male'),
      name_first: 'Jacob',
      name_last: 'Jacobjingheimerschmidt',
      name_pfx: nil,
      name_sfx: nil,
      name_middle: nil,
      addresses: [],
      emails: [],
      phones: []
  end

  let(:life_partner) do
    instance_double Enrollee,
      person: life_partner_person,
      subscriber?: false,
      relationship_status_code: "life partner",
      pre_amt: BigDecimal.new("899.99"),
      coverage_start: Date.today + 1.day,
      coverage_end: Time.now.end_of_year.to_date,
      cp_id: 'carrier_policy_id',
      c_id: 'carrier_member_id'
  end

  before do
    allow(policy).to receive(:plan_id).and_return(plan.id)
    render :template => "enrollment_events/_policy",
      :layout => 'layouts/policy_test',
      :locals => { :policy => policy, :enrollees => [ subscriber, life_partner ] }
  end

  subject { rendered }

  it "should be schema valid" do
    expect(validate_with_schema(Nokogiri::XML(subject))).to eq([])
  end

  before do
    allow(shop_policy).to receive(:plan_id).and_return(plan.id)
    allow(employer_contact).to receive(:id).and_return("1")
    render :template => "enrollment_events/_policy",
      :layout => 'layouts/policy_test',
      :locals => { :address => address, :policy => shop_policy, :enrollees => [ subscriber, life_partner ] }  end

  subject { rendered }

  it "should be schema valid" do
    expect(validate_with_schema(Nokogiri::XML(subject))).to eq([])
  end
end

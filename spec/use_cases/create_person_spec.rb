require 'rails_helper'

describe CreatePerson do

  let(:request) do 
    {
      person: person,
      demographics: demographics
    }
  end
  let(:listener) { double }
  let(:member_id) { "193202" } 

  let(:person) do
    {
      :id => "193202",
      :name_first=>"Person",
      :name_last => "One",
      :name_full=>"Person One",
      :addresses => addresses,
      :phones => phones,
      :emails => emails
      # :relationships => relationships
    }
  end

  let(:phones) do 
    [ 
      { 
        :phone_type=>"home",
        :phone_number=>"202-555-5555"
      } 
    ]
  end

  let(:addresses) do 
    [
      {
        :address_type=>"home", 
        :address_1=>"112 Some St NW", 
        :address_2=>"Unit 555",
        :city=>"Washington", 
        :state=>"district_of_columbia",
        :location_state_code=>"DC", 
        :zip=>"20009"
      }
    ]
  end

  let(:emails) do
    [
      {
        :email_type=>"home",
        :email_address=>"an_email@gmail.com"
      }
    ]
  end

  let(:demographics) do 
    {
      :ssn=>"555555555", 
      :gender=>"female", 
      :dob=>"19860505", 
      :ethnicity=>nil, 
      :race=>nil, 
      :birth_location=>nil, 
      :citizen_status=>"us_citizen", 
      :is_state_resident=>nil, 
      :is_incarcerated=>nil
    }
  end 

  context 'when first name and last name are empty' do
    let(:person) do
      {
        :id => "193202",
        :name_first=> nil,
        :name_last => nil,
      }
    end
    it 'should notify listener of the failure' do
      expect(listener).to receive(:invalid_person)
      expect(subject.validate(request, listener)).to be_false
    end
  end

  context "when gender missing" do
    let(:demographics) {{ :gender=> nil }} 

    it 'should notify listener of the failure' do
      expect(listener).to receive(:invalid_member)
      expect(subject.validate(request, listener)).to be_false
    end
  end
end

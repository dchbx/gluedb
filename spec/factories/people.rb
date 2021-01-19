FactoryGirl.define do
  factory :person do
    name_pfx 'Mr'
    name_first 'John'
    name_middle 'X'
    sequence(:name_last) {|n| "Smith\##{n}" }
    name_sfx 'Jr'

    transient do
      dob Date.today - 35.years 
    end

    after(:create) do |p, evaluator|
      create_list(:member,  2, person: p, dob: evaluator.dob)
      create_list(:address, 2, person: p)
      create_list(:phone,   2, person: p)
      create_list(:email,   2, person: p)
      p.authority_member_id = p.members.first.hbx_member_id
    end

    trait :without_first_name do
      name_first ' '
    end

    trait :without_last_name do
      name_last ' '
    end

    factory :invalid_person, traits: [:without_first_name,
      :without_last_name]
  end
end

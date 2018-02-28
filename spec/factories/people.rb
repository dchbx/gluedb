FactoryGirl.define do
  factory :person do
    name_pfx 'Mr'
    name_first 'John'
    name_middle 'X'
    sequence(:name_last) {|n| "Smith\##{n}" }
    name_sfx 'Jr'

    transient do
      skip_address false
    end

    after(:create) do |p, evaluator|
      create_list(:member, 2, person: p)
      create_list(:address, 2, person: p) unless evaluator.skip_address
      create_list(:phone, 2, person: p)
      create_list(:email, 2, person: p)
      p.authority_member_id = p.members.first.hbx_member_id
      p.save
    end

    trait :without_first_name do
      name_first ' '
    end

    trait :without_last_name do
      name_last ' '
    end

    trait :adult_under_26 do
      after(:create) do |p, evaluator|
        p.members.clear
        create_list(:adult_member_under_26,1,person: p)
      end
    end

    trait :child do
      after(:create) do |p,evaluator|
        p.members.clear
        create_list(:child_member,1,person: p)
      end
    end

    factory :invalid_person, traits: [:without_first_name, :without_last_name]
    factory :under_26_person, traits: [:adult_under_26]
    factory :child_person, traits: [:child]
  end
end

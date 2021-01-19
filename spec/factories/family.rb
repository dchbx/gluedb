FactoryGirl.define do
  factory :family do
    sequence(:e_case_id) {|n| "34534523#{n}" }
  end
end

FactoryGirl.define do
  factory :enrollee do
    sequence(:m_id) { |n| "#{n}"}
    ben_stat 'active'
    emp_stat 'active'
    rel_code 'self'
    ds false
    pre_amt '666.66'
    sequence(:c_id) { |n| "#{n}" }
    sequence(:cp_id) { |n| "#{n}" }
    coverage_start Date.new(2014,1,2)
    coverage_end Date.new(2014,3,4)
    coverage_status 'active'

    trait :self_relationship do
      rel_code 'self'
    end

    trait :canceled_dependent do
        rel_code 'child'
        coverage_end Date.new(2014,1,2)
    end

    factory :subscriber_enrollee, traits: [:self_relationship]
    factory :cancelled_enrollee,  traits: [:canceled_dependent]
  end
end
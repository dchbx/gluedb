FactoryGirl.define do
  factory :policy do
    sequence(:eg_id) { |n| "#{n}" }
    pre_amt_tot '666.66'
    tot_res_amt '111.11'
    tot_emp_res_amt '222.22'
    carrier_to_bill true
    allocated_aptc '1.11'
    elected_aptc '2.22'
    applied_aptc '3.33'
    broker
    plan
    carrier_specific_plan_id 'rspec-mock'
    rating_area  "100"
    composite_rating_tier 'rspec-mock'
    kind 'individual'
    enrollment_kind 'open_enrollment'

    after(:create) do |p, evaluator|
      create_list(:enrollee, 2, policy: p, coverage_start: evaluator.coverage_start, coverage_end: evaluator.coverage_end)
    end

    trait :shop do
      employer
      kind 'employer_sponsored'
      after(:create) do |policy|
        create :premium_payment, employer: policy.employer, carrier: policy.plan.carrier, policy: policy
      end
    end

    trait :terminated do 
      aasm_state "terminated"
    end

    trait :sep do 
      enrollment_kind 'special_enrollment'
    end

    trait :canceled_dependent do 
      after(:create) do |p, evaluator|
        create_list(:enrollee, 2, policy: p)
        create_list(:cancelled_enrollee,1, policy: p)
      end
    end

    transient do
      coverage_start { Date.new(2014,1,2) }
      coverage_end   { Date.new(2014,3,4) }
    end

    factory :shop_policy, traits: [:shop]
    factory :terminated_policy, traits: [:terminated]
    factory :canceled_dependent_policy, traits: [:canceled_dependent]
  end
end

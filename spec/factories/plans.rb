FactoryGirl.define do
  factory :plan do
    sequence(:name) {|n| "Super Plan A #{n}" }
    abbrev 'SPA'
    sequence(:hbx_plan_id)  {|n| "1234#{n}" }
    sequence(:hios_plan_id) {|n| "4321#{n}" }
    coverage_type 'health'
    metal_level 'bronze'
    market_type 'individual'
    ehb 0.0
    carrier { FactoryGirl.create(:carrier) }
    year { Date.today.year }

    after(:create) do |plan, evaluator|
      (14..65).each do |age|
         create(:premium_table, plan: plan, age: age)
      end
    end
  end
end

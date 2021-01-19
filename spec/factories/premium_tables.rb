FactoryGirl.define do
  factory :premium_table do

    rate_start_date { Date.today.beginning_of_year }
    rate_end_date   { Date.today.end_of_year }
    sequence(:age)  { |n| n }
    amount          250.0
    plan
  end
end


FactoryGirl.define do
  factory :employer_contact do
    job_title 'manager'
    department 'HR'
    name_prefix 'Mr.'
    first_name "Joe"
    middle_name "M"
    last_name "Smith"
    name_suffix ""
  
  end
end
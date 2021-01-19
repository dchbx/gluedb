
require File.join(Rails.root,"app","data_migrations","change_enrollee_end_date.rb")

# This rake tasks removes coverage end dates for  members of a policy in Glue. 
#  RAILS_ENV=production bundle exec rake migrations:change_enrollee_end_date eg_id='123456' m_id='234' new_end_date='05/31/2019'

namespace :migrations do 
  desc "Change Enrollee coverage end date"
  ChangeEnrolleeEndDate.define_task :change_enrollee_end_date => :environment
end

require File.join(Rails.root,"app","data_migrations","change_policy_end_date.rb")

# This rake tasks removes end dates from all members of a policy in Glue. 
# format RAILS_ENV=production bundle exec rake migrations:change_policy_end_date eg_ids='123456,123444,123456' end_date='05/31/2021'

namespace :migrations do 
  desc "Change Policy End Date"
  ChangePolicyEndDate.define_task :change_policy_end_date => :environment
end
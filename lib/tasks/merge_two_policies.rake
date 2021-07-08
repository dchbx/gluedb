require File.join(Rails.root,"app","data_migrations","merge_two_policies.rb")

# This rake task merges people in Glue.
# This rake task can update any field of the policy 
# format RAILS_ENV=production bundle exec rake migrations:merge_two_policies policy_to_keep='1' policy_to_remove='2' fields_from_policy_to_remove="pre_amt_tot, tot_res_amt, tot_emp_res_amt, aasm_state"

namespace :migrations do 
  desc "Merge Two Policies"
  MergeTwoPolicies.define_task :merge_two_policies => :environment
end
require File.join(Rails.root,"app","data_migrations","mark_policies_for_non_payment.rb")

# This rake task updates the term_for_np field for the given policies to "true".
# format RAILS_ENV=production bundle exec rake migrations:mark_policies_for_non_payment
# the file that contains the list of policy id's that need to be updated should be included
# at the root level of the rails application and be named policies_to_mark_for_non_payment.txt.
# If an individual policy needs to be updated the id can be passed as an environment level like this:
# RAILS_ENV=production bundle exec rake migrations:mark_policies_for_non_payment policy_id="123123"

namespace :migrations do
  desc "Update term_for_np for policy to true"
  MarkPoliciesForNonPayment.define_task :mark_policies_for_non_payment => :environment
end
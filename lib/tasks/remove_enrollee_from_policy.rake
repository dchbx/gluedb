require File.join(Rails.root,"app","data_migrations","remove_enrollee_from_policy")

# This rake tasks removes enrollees from policy.
# RAILS_ENV=production bundle exec rake migrations:remove_enrollee_from_policy eg_id='123456' m_id='4624327'

namespace :migrations do 
  desc "Remove Enrollee from Policy"
  RemoveEnrolleeFromPolicy.define_task :remove_enrollee_from_policy => :environment
end


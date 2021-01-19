
require File.join(Rails.root,"app","data_migrations","change_enrollee_premium.rb")

# This rake tasks change enrollee premimum amount for  members of a policy in Glue. 
#  RAILS_ENV=production bundle exec rake migrations:change_enrollee_premium eg_id='123456' m_id='234' start_date='01/01/2017' premimum="200"

namespace :migrations do 
  desc "Change Enrollee premimum amount"
  ChangeEnrolleePremium.define_task :change_enrollee_premium => :environment
end


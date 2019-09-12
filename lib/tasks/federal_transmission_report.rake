require File.join(Rails.root,"app","data_migrations","federal_transmission_report.rb")

# This rake tasks change enrollee premimum amount for  members of a policy in Glue. 
#  RAILS_ENV=production bundle exec rake migrations:federal_transmission_report

namespace :migrations do 
  desc "federal transmission report info"
  FederalTransmissionReport.define_task :federal_transmission_report => :environment
end

require File.join(Rails.root,"app","data_migrations","update_npt_indicator.rb")

# This rake task updates the field for the given policy to know its kind of termination.
# Without CSV_FILE Updating NPT rake
# format RAILS_ENV=production bundle exec rake migrations:update_npt_indicator policy_id="1" eg_id="123123" npt_indicator="true" csv_file="false"

# With CSV_FILE updating premium amounts rake and 
# 1.Place a csv file on the root
# 2.Change the csv file name as npt_indicator_list.csv
# 3.Then run the rake
# format RAILS_ENV=production bundle exec rake migrations:update_npt_indicator csv_file="true"
namespace :migrations do
  desc "Update NPT Indicator for Policies"
  UpdateNptIndicator.define_task :update_npt_indicator => :environment
end

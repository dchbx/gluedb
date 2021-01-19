require File.join(Rails.root,"app","data_migrations","update_total_responsible_amount.rb")

# This rake task updates the kind field for the given policy to "coverall".
# Without CSV_FILE Updating Premium Amounts rake
# format RAILS_ENV=production bundle exec rake migrations:update_total_responsible_amount eg_id="123123" total_responsible_amount="123.22" premium_amount_total="22.11" applied_aptc="0" employer_contribution="123" csv_file="false"

# With CSV_FILE updating premium amounts rake and 
# 1.Place a csv file on the root
# 2.Change the csv file name as policy_premium_amounts.csv
# 3.Then run the rake
# format RAILS_ENV=production bundle exec rake migrations:update_total_responsible_amount csv_file="true"
namespace :migrations do
  desc "Update Total Responsible Amount"
  UpdateTotalResponsibleAmount.define_task :update_total_responsible_amount => :environment
end

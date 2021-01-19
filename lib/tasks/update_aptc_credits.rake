require File.join(Rails.root,"app","data_migrations","update_aptc_credits.rb")

  # This rake task merges people in Glue.
  #Below rake is to delete aptc credit
    # format RAILS_ENV=production bundle exec rake migrations:update_aptc_credits policy_id="304676" aptc="0" start_on="1/1/2018" end_on="9/30/2018" delete_credit="true"
  #Below rake is to create a new aptc credit 
    # format RAILS_ENV=production bundle exec rake migrations:update_aptc_credits policy_id="304676" aptc="200" start_on="1/1/2018" end_on="9/30/2018" pre_amt_tot="300" tot_res_amt="100" delete_credit="nil"

namespace :migrations do 
  desc "Update Aptc Credits"
  UpdateAptcCredits.define_task :update_aptc_credits => :environment
end

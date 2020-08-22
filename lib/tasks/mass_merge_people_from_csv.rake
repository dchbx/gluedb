require File.join(Rails.root,"app", "data_migrations", "mass_merge_people_from_csv.rb")

# This rake task provides 
# Use this in association with rake task
# app/data_migrations/merge_duplicate_people.rb
# Duplicate person merging task often require looking through
# a CSV and looping through the authority member id's in the console to
# extract the Mongo ID's, so this task can speed up the process
# by taking in an input of a CSV file with a list of authority member ID's (person to keep) in one column with the
# non authority members (person to merge) in the column next to it:
# format RAILS_ENV=production bundle exec rake migrations:mass_merge_people_from_csv csv_filename='csv_filename.csv'

namespace :migrations do 
  desc "Mass Merges Person Records from CSV"
  MassMergePeopleFromCSV.define_task :mass_merge_people_from_csv => :environment
end
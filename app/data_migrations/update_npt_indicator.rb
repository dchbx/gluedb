# Changes the kind field on a policy for NPT indicator
require 'csv'
require File.join(Rails.root, "lib/mongoid_migration_task")
class UpdateNptIndicator < MongoidMigrationTask

  def migrate
    if ENV['csv_file'] == "true"
      file_name = (
                    if Rails.env.production? 
                      "#{Rails.root}/npt_indicator_list.csv" 
                    elsif Rails.env.test?
                      "#{Rails.root}/spec/data_migrations/test_npt_indicator_list.csv"
                    end
                    )
      update_npt_indicator_with_csv(file_name)
    elsif ENV['csv_file'] == "false"
      update_npt_indicator_without_csv
    end
  end

  def update_npt_indicator_with_csv(file_name)
    CSV.read(file_name).each do |row|
      # Skips the header Row
      next if CSV.read(file_name)[0] == row
      # Removes nil values (blank cells) from row array
      row = row.compact
      # Skips entirely blank rows
      next if row.length == 0
      policy_id = row[0]
      eg_id = row[1]
      npt_indicator = row[2]
      update_npt_indicator(policy_id, eg_id, npt_indicator)
    end
  end

  def update_npt_indicator_without_csv
    policy_id = ENV['policy_id']
    eg_id = ENV['eg_id']
    npt_indicator = ENV['npt_indicator']
    update_npt_indicator(policy_id, eg_id, npt_indicator)
  end

  def update_npt_indicator(policy_id, eg_id, npt_indicator)
    policy = Policy.find(policy_id)
    if policy.hbx_enrollment_ids.include?(eg_id)
      policy.update_attributes!(term_for_np: npt_indicator)
      policy.save!
      puts "Successfully updated npt_indicator for eg_id:#{policy.eg_id}" unless Rails.env.test?
    else
      puts "Policy not found for eg_id:#{eg_id}" unless Rails.env.test?
    end
  end
end 

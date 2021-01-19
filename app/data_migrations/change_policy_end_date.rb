# Changes/Addes end dates to policies
require File.join(Rails.root, "lib/mongoid_migration_task")

class ChangePolicyEndDate < MongoidMigrationTask
  def deactivate_enrollees(policy)
    policy.enrollees.each do |enrollee|
      enrollee.emp_stat = "terminated"
      enrollee.coverage_status = "inactive"
      enrollee.coverage_end = ENV['end_date'].to_date
      enrollee.save!
    end
  end

  def change_aasm_state(policy)
    if policy.policy_start == ENV['end_date'].to_date
      policy.aasm_state = 'canceled'
    elsif policy.policy_start != ENV['end_date'].to_date
      policy.aasm_state = 'terminated'
    end
    policy.save!
  end

  def migrate
    eg_ids=ENV['eg_ids'].split(',').uniq
    eg_ids.each do |eg_id|
      policy = Policy.where(hbx_enrollment_ids: eg_id).first
      if policy.nil?
        puts "Policy not found with this eg_id: #{eg_id}"
      else
        begin
          deactivate_enrollees(policy)
          change_aasm_state(policy)
          puts "Changed end date for policy #{eg_id} to #{ENV['end_date']}" unless Rails.env.test?
        rescue => e
          puts "Could not process policy with eg_id: #{eg_id}, error message: #{e.message}"
        end
      end
    end
  end
end

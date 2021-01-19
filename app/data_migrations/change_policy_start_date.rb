# Changes the start date on ALL members of a policy
require File.join(Rails.root, "lib/mongoid_migration_task")
class ChangePolicyStartDate < MongoidMigrationTask

  def move_effective_date(policy,new_start_date)
    policy.enrollees.each do |enrollee|
      enrollee.coverage_start = ENV['new_start_date'].to_date
      enrollee.save
    end
    puts "Changed start date for policy #{ENV['eg_id']} to #{policy.policy_start}" unless Rails.env.test?
  end

  def migrate
    if Policy.where(eg_id: ENV['eg_id']).size > 1
      puts "There are multiple policies for policy #{ENV['eg_id']}. Please resolve before changing effective dates." unless Rails.env.test?
    elsif Policy.where(eg_id: ENV['eg_id']).size == 0
      puts "Policy #{ENV['eg_id']} not found." unless Rails.env.test?
    else
      policy = Policy.where(eg_id: ENV['eg_id']).first
        move_effective_date(policy,ENV['new_start_date'])
    end
  end
end

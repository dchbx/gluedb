require File.join(Rails.root, "lib/mongoid_migration_task")

class RemoveEnrolleeFromPolicy < MongoidMigrationTask
  
  def find_enrollee_to_remove(enrollees,removal_id)
   enrollees.detect{|en| en.m_id == removal_id}
  end

  def migrate
    policy = Policy.where(eg_id: ENV['eg_id']).first
    (puts "No hbx_enrollment was found with the given hbx_id" unless Rails.env.test?) if policy.blank?

    m_id = ENV['m_id']
    removal_enrollee = find_enrollee_to_remove(policy.enrollees,m_id)
    (puts "Enrollee not found" unless Rails.env.test?) if removal_enrollee.blank?

    removal_enrollee.destroy
    policy.save
    (puts "Enrollee #{m_id} has been removed." unless policy.enrollees.map(&:m_id).include?(m_id)) unless Rails.env.test?  
  end
end
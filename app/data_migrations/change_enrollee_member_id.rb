# Changes an Enrollee's Member ID 
require File.join(Rails.root, "lib/mongoid_migration_task")

class ChangeEnrolleeMemberId < MongoidMigrationTask

  def migrate
    policy = Policy.where(eg_id: ENV['eg_id']).first
    (raise "This policy cannot be found." if policy.blank?) unless Rails.env.test?
    enrollee = policy.enrollees.detect{|en| en.m_id == ENV['old_hbx_id']}
    (raise "This enrollee cannot be found." if enrollee.blank?) unless Rails.env.test? 
    enrollee.update_attributes(:m_id => ENV['new_hbx_id'])
    puts "Member ID of Enrollee was changed from #{ENV['old_hbx_id']} to #{enrollee.m_id}" unless Rails.env.test?
  end
end
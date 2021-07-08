require File.join(Rails.root, "lib/mongoid_migration_task")

class MergeTwoPolicies < MongoidMigrationTask

  def migrate
    begin
      policy_to_keep = Policy.where(eg_id: ENV['policy_to_keep']).first
      policy_to_remove = Policy.where(eg_id: ENV['policy_to_remove']).first
      fields_from_policy_to_remove = ENV['fields_from_policy_to_remove'].split(", ")
      if (policy_to_keep.present? && policy_to_remove.present? && fields_from_policy_to_remove.present? && policy_to_keep != policy_to_remove)
        merge_two_policies(policy_to_keep, policy_to_remove, fields_from_policy_to_remove)
      else 
        raise "Policy_to_keep or Policy_to_keep or fields_from_policy_to_remove - not found or You have entered same eg_id" unless Rails.env.test?
      end
    rescue => e
      puts "Errors: #{e}" unless Rails.env.test?
    end
  end

  def merge_two_policies(policy_to_keep, policy_to_remove, fields_from_policy_to_remove)
    existing_enrollees = policy_to_keep.enrollees.map(&:m_id)
    enrollees_to_move = policy_to_remove.enrollees.where(:m_id => {"$nin" => existing_enrollees}).to_a
    policy_to_keep.enrollees += enrollees_to_move
    policy_to_keep.hbx_enrollment_ids += policy_to_remove.hbx_enrollment_ids
    policy_to_keep.hbx_enrollment_ids.uniq!
    fields_from_policy_to_remove.each do |field|
      policy_to_keep.assign_attributes(field.to_sym => policy_to_remove.send(field.to_sym))
    end
    
    policy_to_remove.update_attributes!(eg_id: "#{policy_to_remove.eg_id} - DO NOT USE")
    
    policy_to_remove.hbx_enrollment_ids.each do |id|      
      policy_to_remove.hbx_enrollment_ids.clear.push("#{id} - DO NOT USE")
      policy_to_remove.save!
    end

    policy_to_keep.save!
    puts "updated sucessfully with policy values #{policy_to_keep} " unless Rails.env.test? 
  end
end

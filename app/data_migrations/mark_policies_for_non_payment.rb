# Updates policies that have been terminated/cancelled for non-payment
require File.join(Rails.root, "lib/mongoid_migration_task")
class MarkPoliciesForNonPayment < MongoidMigrationTask

  def migrate
    if ENV['policy_id'].nil?
      policies = File.open("#{Rails.root}/policies_to_mark_for_non_payment.txt", "r")
      policies.each do |policy_id|
        p = Policy.find(policy_id)
        if (p && p.aasm_state == "terminated") || (p && p.aasm_state == "cancelled")
          p.term_for_np = true
        end
        p.save!
      end
      policies.close
    else
      #update individual policy
      p = Policy.find(ENV['policy_id'])
      if (p && p.aasm_state == "terminated") || (p && p.aasm_state == "cancelled")
        p.term_for_np = true
      end
      p.save!
    end
  end
end
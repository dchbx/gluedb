# Removes Carriers, Carrier Profiles, and Plans Associated with Carriers
require File.join(Rails.root, "lib/mongoid_migration_task")

class RemoveCarrier < MongoidMigrationTask
  def remove_carrier
    carrier_size = Carrier.where(abbrev: ENV['abbrev']).size
    if carrier_size > 1
      puts "Multiple carriers found with this abbreviation" unless Rails.env.test?
      return
    elsif carrier_size == 0 
      puts "Carrier not found with this abbreviation." unless Rails.env.test?
    elsif carrier_size == 1
      carrier = Carrier.where(abbrev: ENV['abbrev']).first
      carrier_name = carrier.name
      if carrier.carrier_profiles.size > 0
        carrier.carrier_profiles.each do |cp|
          cp.destroy
        end
      end
      carrier.destroy
      puts "Removed #{carrier_name} with abbreviation #{ENV['abbrev']}" unless Rails.env.test?
    end
  end

  def remove_plans
    carrier_size = Carrier.where(abbrev: ENV['abbrev']).size
    if carrier_size > 1
      puts "Multiple carriers found with this abbreviation" unless Rails.env.test?
      return
    elsif carrier_size == 0 
      puts "Carrier not found with this abbreviation." unless Rails.env.test?
    elsif carrier_size == 1
      carrier = Carrier.where(abbrev: ENV['abbrev']).first
      carrier_name = carrier.name
      plans = Plan.where(carrier_id: carrier._id)
      plan_size = plans.size
      plans.each do |plan|
        plan.destroy
      end
      puts "Removed #{plan_size} plans for carrier #{carrier_name}" unless Rails.env.test?
    end
  end

  def migrate
    remove_plans
    remove_carrier
  end
end
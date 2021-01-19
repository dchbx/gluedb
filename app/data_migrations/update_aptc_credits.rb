require File.join(Rails.root, "lib/mongoid_migration_task")
class UpdateAptcCredits < MongoidMigrationTask

  def migrate   

    policy = Policy.find(ENV['policy_id'])
    start_on = ENV['start_on']
    aptc = ENV['aptc']
    end_on = ENV['end_on']
    pre_amt_tot = ENV['pre_amt_tot']
    tot_res_amt = ENV['tot_res_amt']
    
    unless policy.present?
      puts  "Could not find a policy with the id #{ENV['eg_id']}" unless Rails.env.test?
    end
    
    credit = policy.aptc_credits.where(start_on: start_on).first 

    if ENV['delete_credit'] == "true"
      if credit.present?
        credit.destroy
        policy.save!
        puts "Credit deleted" unless Rails.env.test?
        return
      else 
        puts "Could not find that credit to delete" unless Rails.env.test?
      end
    end

    if credit && credit.end_on == end_on
      credit.update_attributes!(aptc: aptc) 
      calculate_amounts(credit, policy)
      puts "APTC credit has been updated to pre_amt_tot: #{credit.pre_amt_tot}, tot_res_amt #{credit.tot_res_amt}, aptc amount: #{credit.aptc}" unless Rails.env.test?
    elsif credit && end_on != credit.end_on 
      credit.update_attributes!(aptc: aptc, end_on: end_on) 
      calculate_amounts(credit, policy)
      puts "APTC credit has been updated to pre_amt_tot: #{credit.pre_amt_tot}, tot_res_amt #{credit.tot_res_amt}, aptc amount: #{credit.aptc}, end_on: #{credit.end_on}" unless Rails.env.test?
    else
      credit = policy.aptc_credits.create!(start_on: start_on, end_on: end_on, pre_amt_tot: pre_amt_tot, tot_res_amt: tot_res_amt, aptc: aptc) if credit.nil?
      calculate_amounts(credit, policy)
      puts "New aptc credit has been created for policy #{policy.eg_id} with pre_amt_tot: #{credit.pre_amt_tot}, tot_res_amt #{credit.tot_res_amt}, aptc amount: #{credit.aptc}  start_on: #{credit.start_on}, end_on: #{credit.end_on}" unless Rails.env.test?
    end
  end

  def calculate_amounts(credit, policy)
    credit.tot_res_amt = credit.pre_amt_tot - credit.aptc
    policy.save!
    policy.tot_res_amt = credit.tot_res_amt
    policy.pre_amt_tot = credit.pre_amt_tot
    policy.save!
  end
end

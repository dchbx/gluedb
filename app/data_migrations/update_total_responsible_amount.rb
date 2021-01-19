# Changes the kind field on a policy for premium amounts
require 'csv'
require File.join(Rails.root, "lib/mongoid_migration_task")
class UpdateTotalResponsibleAmount < MongoidMigrationTask

  def migrate
    if ENV['csv_file'] == "true"
      file_name = (
                    if Rails.env.production? 
                      "#{Rails.root}/policy_premium_amounts.csv" 
                    elsif Rails.env.test?
                      "#{Rails.root}/spec/data_migrations/test_policy_premium_amounts.csv"
                    end
                    )
      update_policies_with_csv(file_name)
    elsif ENV['csv_file'] == "false"
      update_policy_without_csv
    end
  end

  def update_policy_without_csv
    eg_id = ENV['eg_id']
    tot_res_amt= ENV['total_responsible_amount']
    pre_amt_tot = ENV['premium_amount_total']
    tot_emp_res_amt = ENV['employer_contribution']
    update_premium_amounts(eg_id, tot_res_amt, pre_amt_tot, tot_emp_res_amt)
  end

  def update_policies_with_csv(file_name)
    CSV.read(file_name).each do |row|
      # Skips the header Row
      next if CSV.read(file_name)[0] == row
      # Removes nil values (blank cells) from row array
      row = row.compact
      # Skips entirely blank rows
      next if row.length == 0
      eg_id = row[1]
      pre_amt_tot = row[2]
      tot_emp_res_amt = row[3]
      tot_res_amt = row[4]
      update_premium_amounts(eg_id, tot_res_amt, pre_amt_tot, tot_emp_res_amt) 
    end
  end

  def update_premium_amounts(eg_id, tot_res_amt, pre_amt_tot, tot_emp_res_amt)
    policy = Policy.where(eg_id: eg_id).first
    if policy.present? && policy.aptc_credits.empty?
      policy.update_attributes(tot_res_amt: tot_res_amt) if is_number?(tot_res_amt)
      policy.update_attributes(pre_amt_tot: pre_amt_tot) if is_number?(pre_amt_tot)
      policy.update_attributes(tot_emp_res_amt: tot_emp_res_amt) if is_number?(tot_emp_res_amt)
      policy.save!
      puts "Successfully updated premium amounts eg_id:#{policy.eg_id}, tot_res_amt:#{policy.tot_res_amt.to_f}, pre_amt_tot:#{policy.pre_amt_tot.to_f}, tot_emp_res_amt:#{policy.tot_emp_res_amt.to_f}" unless Rails.env.test?
    else
      puts "Policy not found for eg_id:#{eg_id}" unless Rails.env.test?
    end
  end

  def is_number?(string)
    true if Float(string) rescue false
  end
end 

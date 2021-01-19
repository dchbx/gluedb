year = '2019'

puts "Importing #{year} plans"
plan_file = File.open("db/seedfiles/#{year}_plans.json", "r")
data = plan_file.read
plan_file.close
plan_data = JSON.load(data)
puts "Before: total #{Plan.count} plans"
puts "#{plan_data.size} plans in json file"
plan_data.each do |pd|
  plan = Plan.where(year: year.to_i).and(hios_plan_id:pd["hios_plan_id"]).first
  if plan.blank?
    plan = Plan.new(pd)
    plan.id = pd["id"]
    plan.save!
  else
    new_data = pd.dup
    new_data.delete("id")
    plan.update_attributes(new_data)
  end
end
puts "After: total #{Plan.count} plans"
puts "Finished importing #{year} plans"
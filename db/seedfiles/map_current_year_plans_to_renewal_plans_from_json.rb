year = '2019'

puts "Importing #{year} plans"
plan_file = File.open("db/seedfiles/#{year}_plans.json", "r")
data = plan_file.read
plan_file.close
plan_data = JSON.load(data)
counter = 0
puts "#{plan_data.size} plans in json file"
plan_data.each do |pd|
  next if pd["renewal_plan_hios_id"].blank?
  plan = Plan.where(year:year).and(hios_plan_id:pd["hios_plan_id"]).first
  renewal_plan = Plan.where(year: (year.to_i + 1).to_s, hios_plan_id: pd["renewal_plan_hios_id"]).first
  plan.renewal_plan = renewal_plan
  plan.save!
  counter += 1
end
puts "#{counter} #{year} year plans updated with renewal_plan_id"
puts "Finished importing #{year} plans"
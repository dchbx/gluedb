Carrier.all.each do |carrier|
  carrier.update_attributes(plan_change_renewal_dependent_add_transmitted_as_renewal: true)
end
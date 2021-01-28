Carrier.all.each do |carrier|
  carrier.update_attributes(renewal_dependent_add_transmitted_as_renewal: true)
end
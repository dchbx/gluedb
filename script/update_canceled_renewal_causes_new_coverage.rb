Carrier.all.each do |carrier|
  carrier.update_attributes(canceled_renewal_causes_new_coverage: true)
end

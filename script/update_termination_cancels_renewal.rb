Carrier.all.each do |carrier|
  carrier.update_attributes(termination_cancels_renewal: true)
end
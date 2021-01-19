Carrier.all.each do |carrier|
  carrier.update_attributes(retro_renewal_transmitted_as_renewal: true)
end
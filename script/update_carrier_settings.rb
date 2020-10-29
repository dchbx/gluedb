Carrier.all.each do |carrier|
  carrier.update_attributes(termination_cancels_renewal: true,
                            renewal_dependent_add_transmitted_as_renewal: true,
                            renewal_dependent_drop_transmitted_as_renewal: true,
                            plan_change_renewal_dependent_add_transmitted_as_renewal: true,
                            plan_change_renewal_dependent_drop_transmitted_as_renewal: true,
                            retro_renewal_transmitted_as_renewal: true)
end


policies = Policy.all


policies.each do |policy|
  # Update IVL
  if !policy.is_shop?
    policy.carrier_to_bill = true
    policy.save!
    puts("Policy " + policy.id.to_s + " carrier_to_bill set to true.")
  end
end
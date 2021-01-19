 Carrier.all.each do |carrier|
   unless carrier.hbx_carrier_id == "116036"
     carrier.update_attributes(requires_reinstate_for_earlier_termination: true)
   end
 end

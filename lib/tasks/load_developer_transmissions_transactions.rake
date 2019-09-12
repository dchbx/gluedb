namespace :developer do
  desc "Load Demo Transmissions and Transactions"
  task :load_transmissions_transactions => :environment do
    transmission = Protocols::X12::Transmission.create!(ic_sender_id: "1", ic_receiver_id: "2")
    policy = Policy.first
    edi_transaction_set = policy.edi_transaction_sets.build
    edi_transaction_set.ts_id = "1"
    edi_transaction_set.ts_action_code = "2"
    edi_transaction_set.ts_time = Time.now
    edi_transaction_set.ts_date = Date.today
    edi_transaction_set.ts_purpose_code = "00"
    edi_transaction_set.ts_reference_number = "1"
    edi_transaction_set.transaction_kind = "initial_enrollment"
    edi_transaction_set.ts_control_number = "1"
    edi_transaction_set.ts_implementation_convention_reference = "1"
    edi_transaction_set.transmission = transmission
    edi_transaction_set.save!
    # TODO: Trading Partners don't exist for DC Gluedb
    # Sender
    # trading_partner = TradingPartner.create!(name: "Sender")
    # trading_partner = TradingPartner.last
    # trading_profile = trading_partner.trading_profiles.build
    # trading_profile.profile_code = "1"
    # trading_profile.profile_name = "Sender Profile"
    # trading_profile.save!
    # Receiver
    # trading_partner = TradingPartner.create!(name: "Receiver")
    # trading_partner = TradingPartner.where(name: "Receiver").first
    # trading_profile = trading_partner.trading_profiles.build
    # trading_profile.profile_code = "2"
    # trading_profile.profile_name = "Receiver Profile"
    # trading_profile.save!
    puts("Transmission and edi_transaction_set created for first policy.")
  end
end

namespace :developer do
  desc "Load Demo Carrier Profiles"
  task :load_carriers => :environment do
    seed_carrier = Carrier.create!({
      id: Moped::BSON::ObjectId.from_string("5ce6ab2134913261ad000001"),
      hbx_carrier_id: "20014",
      name: "Seed Carrier",
      abbrev: "SEED",
      shp_hlt: true,
      shp_dtl: true,
      ind_dtl: true,
      carrier_profiles: [
        CarrierProfile.new({
          profile_name: "SEED_IVL",
          fein: "999999001"
        }),
        CarrierProfile.new({
          profile_name: "SEED_SHP",
          fein: "999999001"
        })
      ]
    })
    # TODO: There are no Trading Partners in DC Gluedb
    # seed_tp = TradingPartner.create!({
    #  name: "Seed Trading Partner",
    #  trading_profiles: [
    #    TradingProfile.new({
    #      profile_name: "SEED_IVL",
    #      profile_code: "999999001"
    #    }),
    #    TradingProfile.new({
    #      profile_name: "SEED_SHP",
    #      profile_code: "999999001"
    #    })
    #  ]
    # })
    exchange_carrier = Carrier.create!({
      hbx_carrier_id: "20000",
      name: "Seed Exchange",
      abbrev: "EXCHANGE",
      carrier_profiles: [
        CarrierProfile.new({
          profile_name: "EXCHANGE_IVL",
          fein: "999999999"
        }),
        CarrierProfile.new({
          profile_name: "EXCHANGE_SHP",
          fein: "999999999"
        })
      ]
    })
    # exchange_tp = TradingPartner.create!({
    #  name: "Seed Trading Partner",
    #  trading_profiles: [
    #    TradingProfile.new({
    #      profile_name: "EXCHANGE_IVL",
    #      profile_code: "999999999"
    #    }),
    #    TradingProfile.new({
    #      profile_name: "EXCHANGE_IVL",
    #      profile_code: "999999999"
    #    })
    #  ]
    # })
  end
end
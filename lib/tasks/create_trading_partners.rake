namespace :data_migrations do
  desc "Create the trading partners from the existing carrier profiles"
  task :create_trading_partners => :environment do
    Carrier.each do |car|
      trading_profiles = car.carrier_profiles.map do |car_prof|
        TradingProfile.new({
          profile_code: car_prof.fein,
          profile_name: car_prof.profile_name
        })
      end
      TradingPartner.create!({
        name: car.name,
        trading_profiles: trading_profiles
      })
    end
  end
end

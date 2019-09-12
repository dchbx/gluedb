class TradingProfile
  include Mongoid::Document

  embedded_in :trading_partner

  field :profile_code, type: String
  field :profile_name, type: String
end

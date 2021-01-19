class TradingPartner
  include Mongoid::Document

  field :name, type: String

  field :inbound_enrollment_advice_enricher

  embeds_many :trading_profiles
end

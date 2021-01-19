class Carrier
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Versioning
#  include Mongoid::Paranoia


  field :name, type: String
  field :abbrev, as: :abbreviation, type: String
  field :hbx_carrier_id, type: String	# internal ID for carrier
  field :ind_hlt, as: :individual_market_health, type: Boolean, default: false
  field :ind_dtl, as: :individual_market_dental, type: Boolean, default: false
  field :shp_hlt, as: :shop_market_health, type: Boolean, default: false
  field :shp_dtl, as: :shop_market_dental, type: Boolean, default: false
  field :is_active, type: Boolean, default: true
  field :requires_employer_updates_on_enrollments, type: Boolean, default: false
  field :uses_issuer_centric_sponsor_cycles, type: Boolean, default: false
  field :requires_simple_plan_changes, type: Boolean, default: false
  field :requires_simple_renewal, type: Boolean, default: false
  field :requires_reinstate_for_earlier_termination, type: Boolean, default: false
  field :canceled_renewal_causes_new_coverage, type: Boolean, default: false
  field :termination_cancels_renewal, type: Boolean, default: false
  field :renewal_dependent_add_transmitted_as_renewal, type: Boolean, default: false
  field :plan_change_renewal_dependent_add_transmitted_as_renewal, type: Boolean, default: false
  field :plan_change_renewal_dependent_drop_transmitted_as_renewal, type: Boolean, default: false
  field :retro_renewal_transmitted_as_renewal, type: Boolean, default: false
  field :renewal_dependent_drop_transmitted_as_renewal, type: Boolean, default: false

  has_many :plans
  has_many :policies
  has_many :premium_payments
  has_and_belongs_to_many :brokers
#   has_and_belongs_to_many :employers

  embeds_many :carrier_profiles

  before_save :invalidate_find_caches

  index({name: 1})
  index({hbx_carrier_id: 1})
  index({"carrier_profiles.fein" => 1})

  scope :by_name, order_by(name: 1)

  def invalidate_find_caches
    carrier_profiles.each do |c|
      Rails.cache.delete("Carrier/find/carrier_profiles.fein.#{c.fein}")
    end
    Rails.cache.delete("Carrier/find/carrier_profiles.hbx_id.#{hbx_carrier_id}")
    true
  end

  def fein
    carrier_profiles.first.fein
  end

  def self.individual_market_health
  	where(individual_market_health: true)
	end

	def self.individual_market_dental
  	where(individual_market_dental: true)
	end

  def self.shop_market_health
  	where(shop_market_health: true)
	end

	def self.shop_market_dental
  	where(shop_market_dental: true)
	end

  def self.for_hbx_id(hbx_val)
    Rails.cache.fetch("Carrier/find/carrier_profiles.hbx_id.#{hbx_val}") do
      Carrier.where("hbx_carrier_id" => hbx_val).first
    end
  end

  def self.for_fein(c_fein)
    Rails.cache.fetch("Carrier/find/carrier_profiles.fein.#{c_fein}") do
      Carrier.where("carrier_profiles.fein" => c_fein).first
    end
  end

  def shop_profile
    carrier_profiles.where(profile_name: /.*SHP/).first
  end
end

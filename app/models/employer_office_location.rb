class EmployerOfficeLocation 
  include Mongoid::Document

  include MergingModel

  field :name, type: String
  field :is_primary, type: Boolean, default: false

  embeds_one :address, :inverse_of => :employer
  accepts_nested_attributes_for :address, reject_if: :all_blank, allow_destroy: true

  embeds_one :phone, :inverse_of => :employer
  accepts_nested_attributes_for :phone, reject_if: :all_blank, allow_destroy: true

  embedded_in :employer, :inverse_of => :employer_contacts 
  
end

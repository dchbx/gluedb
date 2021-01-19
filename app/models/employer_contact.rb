class EmployerContact
  include Mongoid::Document
  
    field :id, type: String
    field :job_title, type: String
    field :department, type: String
    field :name_prefix, type: String
    field :first_name, type: String
    field :middle_name, type: String
    field :last_name, type: String
    field :name_suffix, type: String
  
    embeds_many :addresses, :inverse_of => :employer_contact
    accepts_nested_attributes_for :addresses, reject_if: :all_blank, allow_destroy: true

    embeds_many :emails, :inverse_of => :employer_contact
    accepts_nested_attributes_for :emails, reject_if: :all_blank, allow_destroy: true
      
    embeds_many :phones, :inverse_of => :employer_contact
    accepts_nested_attributes_for :phones, reject_if: :all_blank, allow_destroy: true
  
    embedded_in :employer, :inverse_of => :employer_contacts 

end

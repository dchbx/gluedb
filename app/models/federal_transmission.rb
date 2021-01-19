class FederalTransmission
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  REPORT_TYPES = %w[ORIGINAL CORRECTED VOID].freeze
  
  field :report_type, type: String, default: "ORIGINAL"
  field :batch_id, type: String
  field :content_file, type: String
  field :record_sequence_number, type: String

  validates_presence_of :report_type, :batch_id, :content_file, :record_sequence_number

  validates_format_of :content_file, :with => /^\d{5}$/, :message => "should be in the form 00001, 00002..."
  
  embedded_in :policy

end
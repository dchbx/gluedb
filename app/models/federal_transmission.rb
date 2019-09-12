class FederalTransmission
  include Mongoid::Document
  include Mongoid::Timestamps::Created

  field :report_type, type: String
  field :batch_id, type: String
  field :content_file, type: String
  field :record_sequence_number, type: String

  embedded_in :policy
end
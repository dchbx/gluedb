module Protocols::LegacyCv
  class LegacyCvTransaction
    include Mongoid::Document
    include Mongoid::Timestamps

     extend Mongorder

     belongs_to :policy, index: true

     mount_uploader :body, EdiBody
    field :submitted_at, type: DateTime
    field :location, type: String
    field :action, type: String
    field :reason, type: String
    field :eg_id, type: String

     validates_presence_of :location, allow_blank: false
    validates_presence_of :submitted_at
    validates_presence_of :policy_id

     index({submitted_at: -1})
    index({submitted_at: -1, eg_id: 1})

     def rejected?
      false
    end

     def transaction_kind
      "Legacy CV"
    end

     def ack_nak_processed_at
      nil
    end

     def aasm_state
      'transmitted'
    end

     def self.default_search_order
      [
        ["submitted_at", 1]
      ]
    end

     def self.search_hash(s_str)
      clean_str = s_str.strip
      s_rex = Regexp.new(Regexp.escape(clean_str), true)
      { "eg_id" => s_rex }
    end
  end
end

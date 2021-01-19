module PdfTemplates
  class ProratedAmount
    include Virtus.model

    attribute :partial_month_premium, String
    attribute :partial_month_aptc, String
    attribute :partial_month_csr, String, :default => '0.0'
    attribute :partial_month_start_date, String
    attribute :partial_month_end_date, String

    def to_csv
        [
            partial_month_premium,
            partial_month_aptc,
            partial_month_start_date,
            partial_month_end_date
        ]
    end

  end


end

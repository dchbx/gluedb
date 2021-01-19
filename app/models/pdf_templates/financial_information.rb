module PdfTemplates
  class FinancialInformation
    include Virtus.model

    attribute :financial_effective_start_date, String
    attribute :financial_effective_end_date, String
    attribute :monthly_premium_amount, String
    attribute :monthly_responsible_amount, String
    attribute :monthly_aptc_amount, String
    attribute :monthly_csr_amount, String, :default => '0.0'
    attribute :csr_variant, String

    attribute :prorated_amounts, [PdfTemplates::ProratedAmount]

    attribute :rating_area, String, :default => 'R-DC001'
    attribute :source_exchange_id, String, :default => 'DC0'

    def to_csv
      [
        financial_effective_start_date,
        financial_effective_end_date,
        monthly_premium_amount,
        monthly_aptc_amount,
        monthly_responsible_amount,
        csr_variant
      ] + prorated_amounts_csv
    end

    def prorated_amounts_csv
      proration_info = prorated_amounts.inject([]) do |data, amount|
        data += amount.to_csv
      end

      (2 - prorated_amounts.size).times do |i|
        proration_info += append_blank_fields(4)
      end

      proration_info
    end

    def append_blank_fields(number)
      number.times.collect{|i| nil}
    end
  end
end

            

          

              


        
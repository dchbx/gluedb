module PdfTemplates
  class SbmiPolicy
    include Virtus.model

    attribute :record_control_number, String # Glue policy id
    attribute :qhp_id, String # HIOS id without csr variant
    attribute :exchange_policy_id, String # Enrollment group id
    attribute :exchange_subscriber_id, String # Subscriber Hbx Member id
    attribute :issuer_policy_id, String  # Optional
    attribute :issuer_subscriber_id, String # Optional
    attribute :coverage_start, String
    attribute :coverage_end, String
    attribute :effectuation_status, String
    attribute :insurance_line_code, String
    attribute :coverage_household, Array[PdfTemplates::SbmiEnrollee]
    attribute :financial_loops, Array[PdfTemplates::FinancialInformation]

    def to_csv
      [
        record_control_number,
        qhp_id,
        exchange_policy_id,
        exchange_subscriber_id,
        coverage_start,
        coverage_end,
        insurance_line_code,
      ] + coverage_household_csv + financial_loops_csv 
    end

    def coverage_household_csv
      household_info = coverage_household.inject([]) do |data, enrollee|
        data += enrollee.to_csv
      end

      (6 - coverage_household.size).times do |i|
        household_info += append_blank_fields(11)
      end

      household_info
    end

    def financial_loops_csv
      financial_loops.inject([]) do |data, financial_loop|
        data += financial_loop.to_csv
      end
    end

    def append_blank_fields(number)
      number.times.collect{|i| nil}
    end
  end
end
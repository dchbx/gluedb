module PdfTemplates
  class RenewalEnrollee
    include Virtus.model

    attribute :name_first, String
    attribute :name_last, String
    attribute :name_middle, String
    attribute :name_sfx, String
    attribute :residency, String
    attribute :citizenship_status, String
    attribute :tax_status, String
    attribute :other_coverage, String
    attribute :household_size, Integer
    attribute :projected_income, String
    attribute :incarcerated, Boolean, :default => false

    def to_csv
      [
        full_name,
        residency,
        citizenship_status,
        incarcerated
      ]
    end

    def full_name
      [name_first, name_middle, name_last, name_sfx].reject(&:blank?).join(' ').downcase.gsub(/\b\w/) {|first| first.upcase }
    end
  end
end
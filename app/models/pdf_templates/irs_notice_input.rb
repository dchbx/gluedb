module PdfTemplates
  class IrsNoticeInput
    include Virtus.model
    attribute :policy_id, String
    attribute :issuer_name, String
    attribute :qhp_id, String
    attribute :recipient_address, PdfTemplates::NoticeAddress
    attribute :recipient, PdfTemplates::Enrollee
    attribute :spouse, PdfTemplates::Enrollee
    attribute :covered_household, Array[PdfTemplates::Enrollee]
    attribute :monthly_premiums, Array[PdfTemplates::MonthlyPremium]
    attribute :has_aptc, Boolean, :default => false
    attribute :yearly_premium, PdfTemplates::YearlyPremium
    attribute :active_policies, String
    attribute :canceled_policies, String
    attribute :corrected_record_seq_num, String
    
    def covered_household_as_of(month, year)
      month_begin = Date.new(year, month, 1)
      month_end = month_begin.end_of_month

      covered_household.select do |member|
        (member.coverage_begin <= month_end) && (member.coverage_end >= month_begin)
      end
    end

    def premium_rec_for(month)
      monthly_premiums.detect {|i| i.serial == month }
    end

    def no_coverage?
      monthly_premiums.empty?
    end

    def no_premium_amount?
      monthly_premiums.detect{|p| p.premium_amount.to_i > 0 }.nil?
    end

    def issuer_fein
      carrier_feins = YAML.load(File.read("#{Rails.root}/config/issuer_feins.yml")).with_indifferent_access
      carrier_feins[self.issuer_name.split.join]
    end


    def issuer_dc_name
      carrier_names = {
        "Aetna" => "Aetna Life Insurance Company",
        "CareFirst" => "Group Hospitalization and Medical Services, Inc.",
        "Kaiser" => "Kaiser Foundation Health Plan of the Mid-Atlantic States, Inc.",
        "United Health Care" => "United Healthcare Insurance Company",
        "CareFirst BlueChoice" => "CareFirst BlueChoice, Inc."
      }
      carrier_names[self.issuer_name]
    end
  end
end
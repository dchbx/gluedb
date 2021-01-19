module PdfTemplates
  class RenewalNoticeInput
    include Virtus.model

    attribute :primary_name, String
    attribute :primary_identifier, String
    attribute :primary_address, PdfTemplates::NoticeAddress

    attribute :covered_individuals, Array[String]
    attribute :tax_household, Array[PdfTemplates::RenewalEnrollee]

    attribute :health_policy, String
    attribute :health_plan_current, String
    attribute :health_aptc_current, String

    attribute :dental_policy, String
    attribute :dental_plan_current, String

    attribute :health_plan_name, String
    attribute :dental_plan_name, String
    attribute :health_premium, String
    attribute :health_aptc, String
    attribute :health_responsible_amt, String
    attribute :dental_premium, String
    attribute :dental_aptc, String
    attribute :dental_responsible_amt, String
    attribute :notice_date, Date

    def to_csv
      [
        primary_name,
        primary_identifier,
        primary_address.to_s,
        health_policy,
        health_plan_current,
        health_plan_name,
        health_premium,
        dental_policy,
        dental_plan_current,
        dental_plan_name,
        dental_premium
      ]
    end

    def to_final_renewal_csv
      [
        primary_name,
        primary_identifier,
        primary_address.to_s,
        health_policy,
        health_plan_name,
        health_premium,
        health_aptc,
        dental_policy,
        dental_plan_name,
        dental_premium,
        dental_aptc
      ]
    end

#+ tax_household.map{|renewal_enrollee| renewal_enrollee.to_csv }.flatten

    def to_tom_csv
      [   
        health_aptc_current,
        health_plan_current,
        health_plan_name,
        health_premium,
        (health_premium.to_f - health_aptc_current.to_f).round(2).to_s,
        dental_plan_current,
        dental_plan_name,
        dental_premium
      ]
    end


  end
end

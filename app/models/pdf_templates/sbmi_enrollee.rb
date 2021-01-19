module PdfTemplates
  class SbmiEnrollee
    include Virtus.model

    attribute :exchange_assigned_memberId, String
    attribute :subscriber_indicator, String
    attribute :issuer_assigned_memberId, String
    attribute :person_last_name, String
    attribute :person_first_name, String
    attribute :person_middle_name, String
    attribute :person_name_suffix, String
    attribute :birth_date, String
    attribute :social_security_number, String
    attribute :gender_code, String, :default => 'U'
    attribute :postal_code, String
    attribute :non_covered_subscriberInd, String, :default => 'N'
    attribute :member_start_date, String
    attribute :member_end_date, String

    def to_csv
        [
            exchange_assigned_memberId,
            subscriber_indicator,
            person_last_name,
            person_first_name,
            person_middle_name,
            person_name_suffix,
            birth_date,
            social_security_number,
            gender_code,
            postal_code,
            #non_covered_subscriberInd,
            member_start_date,
            member_end_date,
        ]
    end
  end

 
end
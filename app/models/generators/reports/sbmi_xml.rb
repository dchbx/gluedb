module Generators::Reports  
  class SbmiXml

    include ActionView::Helpers::NumberHelper
    attr_accessor :folder_path, :sbmi_policy
    
    def serialize
      File.open("#{@folder_path}/#{sbmi_policy.record_control_number}.xml", 'w') do |file|
        file.write builder.to_xml(:indent => 2)
      end
    end

    def builder
      Nokogiri::XML::Builder.new do |xml|
        xml.Policy do |xml|
          serialize_policy(xml)
        end
      end
    end

    def serialize_policy(xml)
      xml.RecordControlNumber sbmi_policy.record_control_number
      xml.QHPId sbmi_policy.qhp_id
      xml.ExchangeAssignedPolicyId sbmi_policy.exchange_policy_id
      xml.ExchangeAssignedSubscriberId sbmi_policy.exchange_subscriber_id
      xml.PolicyStartDate sbmi_policy.coverage_start
      xml.PolicyEndDate sbmi_policy.coverage_end
      xml.EffectuationIndicator sbmi_policy.effectuation_status
      xml.InsuranceLineCode sbmi_policy.insurance_line_code

      grouped_members = sbmi_policy.coverage_household.group_by{|sbmi_member| sbmi_member.exchange_assigned_memberId}

      grouped_members.each do |member_id, covered_individuals|
        serialize_covered_individual(xml, covered_individuals)
      end

      sbmi_policy.financial_loops.each do |financial_info|
        serialize_financial_information(xml, financial_info)
      end
    end

    def serialize_covered_individual(xml, grouped_individuals)
      individual = grouped_individuals[0]
      puts "missing zip #{sbmi_policy.record_control_number}" if individual.postal_code.blank?

      grouped_individuals = grouped_individuals.sort_by{|individual| individual.member_start_date}.group_by{|individual| individual.member_start_date}.collect{|k, v| v[0]}

      xml.MemberInformation do |xml|
        xml.ExchangeAssignedMemberId individual.exchange_assigned_memberId
        xml.SubscriberIndicator individual.subscriber_indicator
        xml.MemberLastName chop_special_characters(individual.person_last_name)
        xml.MemberFirstName chop_special_characters(individual.person_first_name)
        xml.MemberMiddleName chop_special_characters(individual.person_middle_name)
        xml.NameSuffix chop_special_characters(individual.person_name_suffix)
        xml.BirthDate individual.birth_date
        xml.SocialSecurityNumber prepend_zeros(individual.social_security_number, 9)
        xml.PostalCode individual.postal_code
        xml.GenderCode individual.gender_code

        grouped_individuals.each do |individual|
          xml.MemberDates do |xml|
            xml.MemberStartDate individual.member_start_date
            xml.MemberEndDate individual.member_end_date
          end
        end
      end
    end

    def serialize_financial_information(xml, financial_info)
      xml.FinancialInformation do |xml|
        xml.FinancialEffectiveStartDate financial_info.financial_effective_start_date
        xml.FinancialEffectiveEndDate financial_info.financial_effective_end_date
        xml.MonthlyTotalPremiumAmount financial_info.monthly_premium_amount
        xml.MonthlyTotalIndividualResponsibilityAmount financial_info.monthly_responsible_amount
        xml.MonthlyAPTCAmount financial_info.monthly_aptc_amount
        xml.MonthlyCSRAmount financial_info.monthly_csr_amount if financial_info.csr_variant != '01' 
        xml.CSRVariantId financial_info.csr_variant
        xml.RatingArea financial_info.rating_area
        if sbmi_policy.effectuation_status == "Y"
          financial_info.prorated_amounts.each do |proration|
            serialize_prorations(xml, proration, financial_info.csr_variant)
          end
        end
      end
    end

    def serialize_prorations(xml, proration, csr_variant)
      xml.ProratedAmount do |xml|
        xml.PartialMonthEffectiveStartDate proration.partial_month_start_date
        xml.PartialMonthEffectiveEndDate proration.partial_month_end_date
        xml.PartialMonthPremiumAmount proration.partial_month_premium
        xml.PartialMonthAPTCAmount proration.partial_month_aptc
        xml.PartialMonthCSRAmount proration.partial_month_csr if csr_variant != '01'
      end
    end

    private

    def prepend_zeros(number, n)
      return number if number.blank?
      (n - number.size).times { number.prepend('0') }
      number
    end

    def date_formatter(date)
      return if date.nil?
      Date.strptime(date,'%m/%d/%Y').strftime("%Y-%m-%d")
    end

    def chop_special_characters(name)
      return name if name.blank?
      name.gsub(/[!@#$%^&*()=_+|;:,<>?`]/, '').gsub(/[ñáéè]/, {"ñ" => "n", "á" => "a", "é" => "e", "è" => "e", "ì" => "i"})
    end
  end
end
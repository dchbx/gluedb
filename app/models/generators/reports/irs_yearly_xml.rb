module Generators::Reports  
  class IrsYearlyXml
    include ActionView::Helpers::NumberHelper

    attr_accessor :record_sequence_num, :corrected_record_sequence_num, :voided_record_sequence_num, :notice_params

    NS = {
      "xmlns:air5.0" => "urn:us:gov:treasury:irs:ext:aca:air:ty19a",
      "xmlns:irs" => "urn:us:gov:treasury:irs:common",
      "xmlns:batchreq" => "urn:us:gov:treasury:irs:msg:form1095atransmissionupstreammessage",
      "xmlns:batchresp"=> "urn:us:gov:treasury:irs:msg:form1095atransmissionexchrespmessage",
      "xmlns:reqack"=> "urn:us:gov:treasury:irs:msg:form1095atransmissionexchackngmessage",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    NS_OLD = {
      "xmlns:air5.0" => "urn:us:gov:treasury:irs:ext:aca:air:ty18a",
      "xmlns:irs" => "urn:us:gov:treasury:irs:common",
      "xmlns:batchreq" => "urn:us:gov:treasury:irs:msg:form1095atransmissionupstreammessage",
      "xmlns:batchresp"=> "urn:us:gov:treasury:irs:msg:form1095atransmissionexchrespmessage",
      "xmlns:reqack"=> "urn:us:gov:treasury:irs:msg:form1095atransmissionexchackngmessage",
      "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"
    }

    def initialize(notice, options = {})
      # @sequence_num = sequence_num
      @notice = notice
      @notice_params = options
    end

    def fetch_ns
      (notice_params[:calender_year].to_s == "2018") ? NS_OLD : NS
    end

    def serialize
      Nokogiri::XML::Builder.new { |xml|
        xml['batchreq'].Form1095ATransmissionUpstream(fetch_ns) do |xml|
          xml['air5.0'].Form1095AUpstreamDetail(:recordType => "", :lineNum => "0") do |xml|
            serialize_headers(xml)
            serialize_policy(xml)
            serialize_recipient(xml)
            serialize_recipient_spouse(xml)
            serialize_coverage_household(xml) if @notice.covered_household.present?
            serialize_policy_premiums(xml)
          end
        end
      }
    end

    def serialize_headers(xml)
      # xml['air5.0'].RecordSequenceNum @sequence_num
      xml['air5.0'].RecordSequenceNum @notice.policy_id.to_i
      xml['air5.0'].TaxYr notice_params[:calender_year]
      xml['air5.0'].CorrectedInd (corrected_record_sequence_num.present? ? 1 : 0)
      if corrected_record_sequence_num.present?
        ft = Policy.find(corrected_record_sequence_num.to_s).federal_transmissions.where(report_type: /original/i).first
        xml['air5.0'].CorrectedRecordSequenceNum "#{ft.batch_id}|#{ft.content_file}|#{corrected_record_sequence_num}"
      end
      xml['air5.0'].VoidInd (voided_record_sequence_num.present? ? 1 : 0)
      if voided_record_sequence_num.present?
        ft = Policy.find(voided_record_sequence_num.to_s).federal_transmissions.where(report_type: /original/i).first
        xml['air5.0'].VoidedRecordSequenceNum "#{ft.batch_id}|#{ft.content_file}|#{voided_record_sequence_num}"
      end
      xml['air5.0'].MarketplaceId "02.DC*.SBE.001.001"  
    end

    def serialize_policy(xml)
      xml['air5.0'].Policy do |xml|
        xml.MarketPlacePolicyNum @notice.policy_id
        xml.PolicyIssuerNm @notice.issuer_name
        xml.PolicyStartDt date_formatter(@notice.recipient.coverage_start_date)
        xml.PolicyTerminationDt date_formatter(@notice.recipient.coverage_termination_date)
      end
    end

    def serialize_recipient(xml)
      xml['air5.0'].Recipient do |xml|
        serialize_individual(xml, @notice.recipient)
        serialize_address(xml, @notice.recipient_address)
      end
    end

    def serialize_recipient_spouse(xml)
      if @notice.spouse
        xml['air5.0'].RecipientSpouse do |xml|
          serialize_individual(xml, @notice.spouse)
        end
      end
    end

    def serialize_coverage_household(xml)
      xml['air5.0'].CoverageHouseholdGrp do |xml|
        @notice.covered_household.each do |individual|
          xml['air5.0'].CoveredIndividual do |xml|
            xml['air5.0'].InsuredPerson do |xml|
              serialize_individual(xml, individual)
            end
            xml['irs'].CoverageStartDt date_formatter(individual.coverage_start_date)
            xml['irs'].CoverageEndDt date_formatter(individual.coverage_termination_date)
          end
        end
      end
    end

    def serialize_individual(xml, individual)
      xml['air5.0'].OtherCompletePersonName do |xml|
        xml.PersonFirstNm individual.name_first
        xml.PersonMiddleNm individual.name_middle
        xml.PersonLastNm individual.name_last
        xml.SuffixNm individual.name_sfx
      end

      xml['irs'].SSN individual.ssn unless individual.ssn.blank?
      xml['air5.0'].BirthDt date_formatter(individual.dob) unless individual.dob.blank?
    end

    def serialize_address(xml, address)
      xml['air5.0'].USAddressGrp do |xml|
        xml.AddressLine1Txt address.street_1
        xml.AddressLine2Txt address.street_2
        xml['irs'].CityNm address.city
        xml.USStateCd address.state
        xml['irs'].USZIPCd address.zip
        # xml.USZIPExtensionCd
      end
    end
  
    def serialize_policy_premiums(xml)
      xml['air5.0'].RecipientPolicyInformation do |xml|
        xml['air5.0'].JanPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 1)
        end
        xml['air5.0'].FebPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 2)
        end
        xml['air5.0'].MarPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 3)
        end
        xml['air5.0'].AprPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 4)
        end
        xml['air5.0'].MayPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 5)
        end
        xml['air5.0'].JunPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 6)
        end
        xml['air5.0'].JulPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 7)
        end
        xml['air5.0'].AugPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 8)
        end
        xml['air5.0'].SepPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 9)
        end
        xml['air5.0'].OctPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 10)
        end
        xml['air5.0'].NovPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 11)
        end
        xml['air5.0'].DecPremiumInformation do |xml|
          serialize_monthly_premiums(xml, 12)
        end
        xml['air5.0'].AnnualPolicyTotalAmounts do |xml|
          serialize_annual_premiums(xml)
        end   
      end
    end

    def serialize_monthly_premiums(xml, month)
      if month_premium = @notice.monthly_premiums.detect{|p| p.serial == month}
        xml['air5.0'].MonthlyPremiumAmt two_decimal_number(month_premium.premium_amount)
        if @notice.has_aptc
          xml['air5.0'].MonthlyPremiumSLCSPAmt two_decimal_number(month_premium.premium_amount_slcsp)
          xml['air5.0'].MonthlyAdvancedPTCAmt two_decimal_number(month_premium.monthly_aptc)
        else
          xml['air5.0'].MonthlyPremiumSLCSPAmt '0.00'
          xml['air5.0'].MonthlyAdvancedPTCAmt '0.00'
        end
      else
        blank_preimums(xml)
      end
    end

    def blank_preimums(xml)
      xml['air5.0'].MonthlyPremiumAmt '0.00'
      xml['air5.0'].MonthlyPremiumSLCSPAmt '0.00'
      xml['air5.0'].MonthlyAdvancedPTCAmt '0.00'
    end

    def serialize_annual_premiums(xml)
      xml['air5.0'].AnnualPremiumAmt two_decimal_number(@notice.yearly_premium.premium_amount)
      if @notice.has_aptc
        xml['air5.0'].AnnualPremiumSLCSPAmt two_decimal_number(@notice.yearly_premium.slcsp_premium_amount)
        xml['air5.0'].AnnualAdvancedPTCAmt two_decimal_number(@notice.yearly_premium.aptc_amount)
      else
        xml['air5.0'].AnnualPremiumSLCSPAmt '0.00'
        xml['air5.0'].AnnualAdvancedPTCAmt '0.00'
      end
    end

    def date_formatter(date)
      return if date.nil?
      Date.parse(date).strftime("%Y-%m-%d")
    end

    def two_decimal_number(price)
      number_with_precision(price.to_f, precision: 2)
    end
  end
end

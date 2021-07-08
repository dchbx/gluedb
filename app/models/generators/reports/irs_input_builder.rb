module Generators::Reports  
  class IrsInputBuilder
    include MoneyMath

    attr_accessor :notice, :carrier_hash, :npt_policy, :settings, :calender_year, :notice_type
 
    REPORT_MONTHS = 12

    SLCSP_CORRECTIONS = {
      7884 => 721.07,
      8269 => 396.61, 
      8393 => 480.38, 
      12236 => 743.3,
      15585 => 575.26,
      15824 => 486.55,
      19846 => 216.47
    }

    def initialize(policy, options = {})
      @notice_type = options[:notice_type] || false
      @npt_policy = options[:npt_policy] || false
      @policy = policy
      @policy_disposition = PolicyDisposition.new(policy)
      @subscriber = @policy.subscriber.person
      @calender_year = policy.subscriber.coverage_start.year

      # multi_version = options[:multi_version] || false
      # if multi_version
      #   @multi_version_pol = Generators::Reports::MultiVersionAptcLookup.new(policy)
      # end
    end

    def void_notice
      notice_type == 'void'
    end

    def process
      @notice = PdfTemplates::IrsNoticeInput.new
      @notice.issuer_name = @carrier_hash[@policy.carrier_id]

      # Enable for IRS H36
      # if @policy.plan.hios_plan_id.match(/^86052/)
      #   # puts "CareFirst BlueChoice -- #{@policy.id}"
      #   @notice.issuer_name = "CareFirst BlueChoice"
      # end

      # @policy.plan.carrier.name
      @notice.qhp_id = @policy.plan.hios_plan_id.gsub('-','')
      @notice.policy_id = prepend_zeros(@policy.id.to_s, 6)
      # @notice.has_aptc = true if @policy.applied_aptc > 0

      if @policy.responsible_party_id.present? # && ![87085,87244,87653,88495,88566,89129,89702,89922,95250,115487].include?(@policy.id)
        append_responsible_party_address
      else
        append_recipient_address(@subscriber)
      end

      append_policy_enrollees
      if @policy.canceled?
        append_void_monthly_premiums
      else
        void_notice ? append_void_monthly_premiums : append_monthly_premiums
      end

      append_yearly_premiums
      reset_variables
    end

    def append_responsible_party_address
      if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(@policy.responsible_party_id)).first
        @notice.recipient_address = PdfTemplates::NoticeAddress.new(address_to_hash(responsible_party.mailing_address))
      end
    end

    def append_recipient_address(subscriber)
      @notice.recipient_address = PdfTemplates::NoticeAddress.new(address_to_hash(subscriber.mailing_address))
    end

    def append_recipient(person)
      authority_member = person.authority_member
      if authority_member.nil?
        raise "Missing Authority Member"
        return nil 
      end

      @notice.recipient = PdfTemplates::Enrollee.new({
        name: person.full_name,
        ssn: authority_member.ssn,
        dob: format_date(authority_member.dob),
        name_first: person.name_first,
        name_middle: person.name_middle,
        name_last: person.name_last,
        name_sfx: person.name_sfx
        })
    end

    def reset_variables
      @policy_disposition = nil
      @subscriber = nil
      @policy = nil
    end

    def append_policy_enrollees
      if @policy.responsible_party_id.present? # && ![87085,87244,87653,88495,88566,89129,89702,89922,95250,115487].include?(@policy.id)
        if responsible_party = Person.where("responsible_parties._id" => Moped::BSON::ObjectId.from_string(@policy.responsible_party_id)).first
          @notice.recipient = build_responsible_party(responsible_party)
        else
          raise "responsible party not found!!"
        end
      else
        @notice.recipient = build_enrollee_ele(@policy.subscriber)
        @notice.spouse = build_enrollee_ele(@policy.spouse)
      end
      @notice.covered_household = @policy_disposition.enrollees.map{ |enrollee| build_enrollee_ele(enrollee) }.compact unless void_notice
    end

    def build_responsible_party(person)
      PdfTemplates::Enrollee.new({
        name: person.full_name,
        coverage_start_date: format_date(@policy.coverage_period.begin),
        coverage_termination_date: format_date(@policy.coverage_period.end),
        name_first: person.name_first,
        name_middle: person.name_middle,
        name_last: person.name_last,
        name_sfx: person.name_sfx
      })
    end

    def build_enrollee_ele(enrollee)
      return nil if enrollee.blank? || enrollee.person.blank?
      authority_member = enrollee.person.authority_member
      return nil if authority_member.nil?
      coverage_end = enrollee.coverage_end.blank? ? @policy.coverage_period.end : enrollee.coverage_end
      coverage_end = @policy.coverage_period.end if coverage_end > @policy.coverage_period.end
      PdfTemplates::Enrollee.new({
        name: enrollee.person.full_name,
        ssn: authority_member.ssn,
        dob: format_date(authority_member.dob),
        coverage_start_date: format_date(enrollee.coverage_start),
        coverage_termination_date: format_date(coverage_end),
        name_first: enrollee.person.name_first,
        name_middle: enrollee.person.name_middle,
        name_last: enrollee.person.name_last,
        name_sfx: enrollee.person.name_sfx
      })
    end

    def append_void_monthly_premiums
      @notice.monthly_premiums = 12.times.inject([]) do |monthly_premiums, index|
        monthly_premiums << {
          serial: (index + 1),
          premium_amount: 0.0,
          premium_amount_slcsp: 0.0,
          monthly_aptc: 0.0          
        }
      end
    end

    def append_monthly_premiums
      coverage_end_month = @policy_disposition.end_date.month
      # coverage_end_month = coverage_end_month - 1 if (@policy_disposition.end_date.day == 1)

      if @policy_disposition.end_date.year != calender_year || coverage_end_month > REPORT_MONTHS
        coverage_end_month = REPORT_MONTHS
      end

      has_middle_of_month_coverage_end = false
      has_middle_of_month_coverage_begin = false

      if @policy.subscriber.coverage_end.present? && (@policy.subscriber.coverage_end.end_of_month != @policy.subscriber.coverage_end)
        has_middle_of_month_coverage_end = true
      end

      # Prorated Begin dates
      if @policy.subscriber.coverage_start.present? && (@policy.subscriber.coverage_start.beginning_of_month != @policy.subscriber.coverage_start)
        has_middle_of_month_coverage_begin = true
      end

      # Commented to generate premiums only for REPORT_MONTHS
      @notice.monthly_premiums = (@policy_disposition.start_date.month..coverage_end_month).inject([]) do |data, i|

        premium_amount = @policy_disposition.as_of(Date.new(calender_year, i, 1)).ehb_premium

        # if coverage_end_month == i && has_middle_of_month_coverage_end
        #   premium_amount = as_dollars((@policy_disposition.end_date.day.to_f / @policy_disposition.end_date.end_of_month.day) * premium_amount)
        # end

        # Prorated Start Dates
        if @policy_disposition.start_date.month == i && has_middle_of_month_coverage_begin
          premium_amount = as_dollars(((@policy_disposition.start_date.end_of_month.day.to_f - @policy_disposition.start_date.day.to_f + 1.0) / @policy_disposition.start_date.end_of_month.day) * premium_amount)
        end

        if coverage_end_month == i && has_middle_of_month_coverage_end
          premium_amount = as_dollars((@policy_disposition.end_date.day.to_f / @policy_disposition.end_date.end_of_month.day) * premium_amount)
        end

        # NPT's

        if npt_policy
          if @policy.subscriber.coverage_end.present? && ((@policy.subscriber.coverage_end.end_of_month - 1.day) == @policy.subscriber.coverage_end)
            has_middle_of_month_coverage_end = false
          end

          if has_middle_of_month_coverage_end
            if (coverage_end_month - 1) == i
              premium_amount = 0
            end

            if coverage_end_month == i
              premium_amount = nil
            end
          else
            if coverage_end_month == i
              premium_amount = 0
            end
          end
        end

        # if @policy.id == 65209
        #   if i > 3
        #     premium_amount = 0
        #   end
        # end

        premium_amounts = {
          serial: i,
          premium_amount: premium_amount
        }

        # @notice.has_aptc = if @multi_version_pol.present? # && @multi_version_pol.assisted?
        #   true ##@multi_version_pol
        # else
        #   @policy_disposition.as_of(Date.new(calender_year, i, 1)).applied_aptc > 0
        # end

        @notice.has_aptc = @policy_disposition.as_of(Date.new(calender_year, i, 1)).applied_aptc > 0

        if @notice.has_aptc
          # silver_plan_premium = 0
          # if SLCSP_CORRECTIONS[@policy.id]
          #   silver_plan_premium = SLCSP_CORRECTIONS[@policy.id]
          # else
          #   silver_plan = Plan.where({ "year" => 2014, "hios_plan_id" => "94506DC0390006-01" }).first
          #   silver_plan_premium = @policy_disposition.as_of(Date.new(calender_year, i, 1), silver_plan).ehb_premium
          # end

          # aptc_amt = @multi_version_pol.nil? ? 
          # @policy_disposition.as_of(Date.new(calender_year, i, 1)).applied_aptc :
          # @multi_version_pol.aptc_as_of(Date.new(calender_year, i, 1))


          silver_plan = Plan.where({:year => calender_year, :hios_plan_id => settings[:tax_document][calender_year][:slcsp]}).first
          silver_plan_premium = @policy_disposition.as_of(Date.new(calender_year, i, 1), silver_plan).ehb_premium

          # silver_plan_premium = 0

          aptc_amt = @policy_disposition.as_of(Date.new(calender_year, i, 1)).applied_aptc

          # Prorated Start Dates
          if @policy_disposition.start_date.month == i && has_middle_of_month_coverage_begin
            aptc_amt = as_dollars(((@policy_disposition.start_date.end_of_month.day.to_f - @policy_disposition.start_date.day.to_f + 1.0) / @policy_disposition.start_date.end_of_month.day) * aptc_amt)
          end

          if coverage_end_month == i && has_middle_of_month_coverage_end
            aptc_amt = as_dollars((@policy_disposition.end_date.day.to_f / @policy_disposition.end_date.end_of_month.day) * aptc_amt)
          end

          # NPT's

          if npt_policy
            if coverage_end_month == i && (has_middle_of_month_coverage_end || @policy_disposition.end_date != @policy_disposition.end_date.end_of_month)
              aptc_amt = as_dollars((@policy_disposition.end_date.day.to_f / @policy_disposition.end_date.end_of_month.day) * aptc_amt)
            end

            if has_middle_of_month_coverage_end
              if (coverage_end_month - 1) == i
                silver_plan_premium = 0
              end

              if coverage_end_month == i
                silver_plan_premium = nil
                aptc_amt = nil
              end
            else
              if coverage_end_month == i
                silver_plan_premium = 0
              end
            end
          end

          # This was added for failure to pay condition
          # if @policy.id == 65209
          #   if i > 3
          #     silver_plan_premium = 0
          #   end
          # end

          premium_amounts.merge!({
            premium_amount_slcsp: silver_plan_premium,
            monthly_aptc: aptc_amt
          })
        end

        data << ((@notice.has_aptc && premium_amounts[:monthly_aptc].nil?) ? nil : premium_amounts)
      end

      @notice.monthly_premiums.compact!
    end

    def append_yearly_premiums
      yearly_premium = {
        premium_amount: @notice.monthly_premiums.inject(0.0){|sum, premium|  sum + premium.premium_amount.to_f}
      }

      slcsp_amount = @notice.monthly_premiums.inject(0.0){|sum, premium| sum + premium.premium_amount_slcsp.to_f}
      aptc_amount = @notice.monthly_premiums.inject(0.0){|sum, premium| sum + premium.monthly_aptc.to_f}

      if aptc_amount > 0
        yearly_premium.merge!({
          slcsp_premium_amount: slcsp_amount,
          aptc_amount: aptc_amount
        })
      end

      @notice.yearly_premium = PdfTemplates::YearlyPremium.new(yearly_premium)
    end

    private

    def format_date(date)
      return nil if date.blank?
      date.strftime("%m/%d/%Y")
    end

    def address_to_hash(address)
      city = nil
      if address.state.upcase == 'DC' && address.zip.to_s.downcase.strip == address.city.to_s.downcase.strip
        city = 'Washington'
      end

      if address.present?
        {
          street_1: address.address_1,
          street_2: address.address_2,
          city: city || address.city,
          state: address.state,
          zip: address.zip
        }        
      end
    end

    def prepend_zeros(number, n)
      (n - number.to_s.size).times { number.prepend('0') }
      number
    end
  end
end
module PdfTemplates
  class IrsGroup
    include Virtus.model

    attribute :calender_year, Integer
    attribute :identification_num, String
    attribute :households, Array[PdfTemplates::Household]
    attribute :insurance_policies, Array[PdfTemplates::IrsNoticeInput]
    attribute :policies, Array[Policy]

    def coverage_ids
      pol_ids = []
      households.each do |h|
        h.irs_households.each { |i| pol_ids += i.policy_ids }
      end
      pol_ids.flatten.uniq
    end

    def coverage_months(duration_months)
      (1..duration_months).each do |month|
      end
    end

    def irs_households_for_duration(months)
      active_household.irs_households.select do |irs_household| 
        had_coverage(irs_household, months)
      end
    end

    def had_coverage(irs_household, months)
      (1..months).each do |month|
        policies = policies_for_month(month).map(&:id)
        if (irs_household.policy_ids & policies).any?
          return true
        end
      end
      false
    end

    def active_household
      households[0]
    end

    def household_for_month(month)
      if households.count > 1
      else
        households[0]
      end
    end

    def policies_for_month(month)
      end_of_month = Date.new(calender_year, month, 1).end_of_month

      pols = []
      policies.each do |pol|
        if pol.subscriber.coverage_start < end_of_month          
          start_date = pol.policy_start

          end_date = pol.policy_end.blank? ? pol.coverage_period_end : pol.policy_end
          coverage_end_month = end_date.month
          # coverage_end_month = coverage_end_month - 1 if end_date.day == 1 # Proration should work

          coverage_end_month = 12 if calender_year != end_date.year

          pols << pol if (start_date.month..coverage_end_month).include?(month)
        end
      end

      pols.uniq
    end

    def irs_household_coverage_as_of(irs_household, month)
      policies = policies_for_month(month).map(&:id)
      coverages = irs_household.policy_ids & policies

      coverages.inject([]) do |data, coverage|
        data << insurance_policies.detect{|ins_pol| ins_pol.policy_id.to_i == coverage }
      end
    end

    def irs_tax_households(month)
      policies = policies_for_month(month).map(&:id)
      household = household_for_month(month)
      household.tax_households.select{|x| (x.policy_ids & policies).any? }
    end


    def to_csv
      return [] if policies.blank?
      policies.inject([]) do |data, policy|
        insured_policy = insurance_policies.detect{|ip| ip.policy_id.to_i == policy.id.to_i}

        if insured_policy.present?
          if policy.applied_aptc.to_f > 0
            irs_households = active_household.irs_households
          else
            irs_households = active_household.coverage_households
          end

          spouse = nil
          dependents = []

          row = [
            identification_num,
            policy.applied_aptc.to_f > 0 ? irs_households.size : 'N/A'
          ]

          if irs_households.first.present?
            row += [
              irs_households.first.primary.name_first,
              irs_households.first.primary.name_last,
              irs_households.first.primary.ssn,
              irs_households.first.primary.dob
            ]

            spouse = irs_households.first.spouse
            dependents = irs_households.first.dependents.compact
          else
            row += ['','','','']
          end

          row += (spouse.present? ? [spouse.name_first, spouse.name_last, spouse.ssn, spouse.dob] : ['','','',''])

          dependents.each do |dependent|
            row += [dependent.name_first, dependent.name_last, dependent.ssn, dependent.dob]
          end

          dependent_count = dependents.size
          (5 - dependent_count).times do |i|
            row += ['', '', '', '']
          end

          row += [
            insured_policy.policy_id,
            insured_policy.qhp_id,
            insured_policy.issuer_name,
            insured_policy.issuer_fein,
            insured_policy.covered_household.first.coverage_start_date,
            insured_policy.covered_household.first.coverage_termination_date
          ]

          6.times do |i|
            monthly_premium = insured_policy.monthly_premiums.detect{|mp| mp.serial == i}
            row += monthly_premium.present? ? [monthly_premium.premium_amount, monthly_premium.premium_amount_slcsp, monthly_premium.monthly_aptc] : ['', '', '']           
          end

          data << row
        else
          puts "----unable to find---#{insurance_policies.map(&:policy_id)}---#{policy.id}"
          data
        end
      end
    end
  end
end
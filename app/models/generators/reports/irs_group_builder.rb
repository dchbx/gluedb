require 'ostruct'

module Generators::Reports 
  class IrsGroupBuilder

    attr_accessor :irs_group, :calender_year, :carrier_hash, :npt_policies, :settings

    def initialize(family)
      @family = family
      @irs_group = PdfTemplates::IrsGroup.new
      @carrier_hash = {}
    end

    def process
      @irs_group.identification_num = @family.irs_groups.first.hbx_assigned_id
      @irs_group.calender_year = @calender_year
      build_households
      build_insurance_policies
    end

    def build_insurance_policies
      pols = @irs_group.coverage_ids.map {|id| Policy.find(id)}
      # pols = get_valid_policies(@irs_group.coverage_ids)

      if pols.empty?
        raise 'No valid policies to report!!'
      end

      @irs_group.policies = pols
      @irs_group.insurance_policies = pols.inject([]) do |data, pol| 
        data << build_policy(pol)
      end
    end

    def build_policy(pol)
      builder = Generators::Reports::IrsInputBuilder.new(pol)
      builder.carrier_hash = @carrier_hash
      if @npt_policies.include?(pol.id.to_s)
        builder.npt_policy = true
        puts "found NPT policy ---- #{pol.id}"
      end
      builder.settings = settings
      builder.process
      
      notice = builder.notice
      if notice.covered_household.empty?
        puts "coverage household is empty!"
      end

      # if notice.monthly_premiums.empty?
      # puts pol.id.to_s
      #   puts notice.monthly_premiums.inspect
      #   puts pol.id.to_s
      # end

      if notice.monthly_premiums.reject{|mp| mp.premium_amount.nil? }.map{|mp| mp.premium_amount }.inject(:+) == 0
        puts "Total monthly premiums is zero"
      end

      builder.notice
    end

    # Lets assume we have only one household
    def build_households
      households = []

      @family.households.each do |household|
        if household.has_aptc?(@calender_year)
          households << build_household_for_aptc(household)
        else
          households << build_household_for_nonaptc(household)
        end
      end

      @irs_group.households = households
    end

    def build_household_for_aptc(household)
      tax_households = household.tax_households

      if tax_households.detect {|th| th.primary.blank? }
        tax_households = build_taxhouseholds_from_enrollments(household)
      else
        if tax_households.count > 1
          tax_households.reject! {|th| th.coverage_policies(@calender_year).empty? } 
          tax_households = TaxHousehold.filter_duplicates(tax_households)
        end

        tax_pols = TaxHousehold.filter_duplicates(tax_households).inject([]) { |data, th| 
          data += th.coverage_policies(@calender_year)
        }

        active_pols = household.enrollments_for_year(@calender_year).map(&:policy).select{|policy| policy.subscriber.coverage_start < Date.today.beginning_of_month}
        if tax_households.empty? || (active_pols - tax_pols.flatten).any?
          tax_households = build_taxhouseholds_from_enrollments(household)
        else
          tax_households = tax_households.map{|th| build_tax_household(th)}
        end
      end

      PdfTemplates::Household.new({
        tax_households: tax_households,
        has_aptc: true
        })
    end

    def build_taxhouseholds_from_enrollments(household)
      policies = household.enrollments_for_year(@calender_year).map(&:policy).select{|policy| policy.subscriber.coverage_start < Date.today.beginning_of_month}

      pols_by_subscriber = policies.inject({}) do |data, policy|
        (data[policy.subscriber.person] ||= []) << policy
        data
      end

      if pols_by_subscriber.length > 1
        ref_policy = policies.detect{|policy| policy.spouse.present?}
        if ref_policy && pols_by_subscriber[ref_policy.spouse.person].present?
          pols_by_subscriber[ref_policy.subscriber.person] += pols_by_subscriber.delete(ref_policy.spouse.person)
        end
      end

      pols_by_subscriber.inject([]) do |tax_households, (subscriber, policies)|
        policy = policies.first

        if policies.any?{|policy| policy.spouse.present?}
          spouse = policies.detect{|policy| policy.spouse.present?}.spouse.person
        end
        dependents = policies.flat_map(&:dependents).flat_map(&:person).uniq
        tax_households << build_tax_household( 
          OpenStruct.new( 
            primary: policy.subscriber.person, 
            spouse: spouse, 
            dependents: dependents,
            coverage_policy_ids: policies.map(&:id)
            )
          )
      end
    end

    def build_household_for_nonaptc(household)
      coverage_households = []

      household.policy_coverage_households(@calender_year).each do |coverage_household|

        coverage_household[:policy_ids] = coverage_household[:policy_ids].map{|id| Policy.find(id)}.select{|policy| policy.subscriber.coverage_start < Date.today.beginning_of_month}.map(&:id)
        if coverage_household[:policy_ids].present?
          coverage_households << PdfTemplates::CoverageHousehold.new({
            primary: build_enrollee(coverage_household[:primary], true),
            policy_ids: coverage_household[:policy_ids]
            })
        end
      end

      PdfTemplates::Household.new({
        coverage_households: coverage_households
        }) 
    end

    def build_tax_household(tax_household)
      coverage_policy_ids = nil
      coverage_policy_ids = tax_household.coverage_policies(@calender_year).select{|policy| policy.subscriber.coverage_start < Date.today.beginning_of_month}.map(&:id) if tax_household.class.to_s == 'TaxHousehold' 

      PdfTemplates::TaxHousehold.new({
        primary: build_tax_member(tax_household.primary, true),
        spouse:  build_tax_member(tax_household.spouse), 
        dependents: tax_household.dependents.map{ |dependent| build_tax_member(dependent) },
        policy_ids: (coverage_policy_ids || tax_household.coverage_policy_ids)
        })
    end

    def build_tax_member(household_member, is_primary = false)
      return unless household_member
      if household_member.class.to_s == 'TaxHouseholdMember'
        person = household_member.family_member.person
        build_enrollee(person, is_primary)
      else
        build_enrollee(household_member, is_primary)
      end
    end

    def build_enrollee(person, is_primary = false)
      member = person.authority_member
      return if member.blank?

      PdfTemplates::Enrollee.new({
        name: person.full_name,
        ssn: member.ssn,
        dob: format_date(member.dob),
        name_first: person.name_first,
        name_middle: person.name_middle,
        name_last: person.name_last,
        name_sfx: person.name_sfx,
        address: build_address(person, is_primary)
        })
    end

    def build_address(person, is_primary)
      address = person.addresses[0]
      address ||= @primary_address

      if is_primary
        if address.nil?
          raise 'Primary address missing'
        else
          @primary_address = address
        end
      end

      PdfTemplates::NoticeAddress.new({
        street_1: address.address_1,
        street_2: address.address_2,
        city: address.city,
        state: address.state,
        zip: address.zip
      })
    end

    # def build_insurance_policies
    #   pols = get_valid_policies(@irs_group.policy_ids)
    #   if pols.empty?
    #     raise 'No valid policies to report!!'
    #   end

    #   @irs_group.insurance_policies = pols.inject([]) do |data, pol| 
    #     data << Generators::Reports::IrsInputBuilder.new(pol).notice
    #   end
    # end
    
    # def build_taxhouseholds
    #   tax_households = []

    #   @family.households.each do |household| 
    #     if @family.has_aptc?(@calender_year)
    #       tax_households << household.tax_households
    #     else
    #       tax_households << household.irs_coverage_households
    #     end
    #   end

    #   tax_households.flatten!
    #   @irs_group.tax_households = tax_households.inject([]) do |data, tax_household| 
    #     data << build_taxhousehold(tax_household)
    #   end
    # end

    # def build_taxhousehold(tax_household)
    #   coverages = (1..@months).inject([]) do |data, month| 
    #     data << build_household_coverage(tax_household, month)
    #   end

    #   PdfTemplates::TaxHousehold.new({
    #     tax_household_coverages: coverages
    #   })    
    # end

    # def build_household_coverage(tax_household, month)
    #   PdfTemplates::TaxHouseholdCoverage.new({
    #     calender_month: month,
    #     primary: build_tax_member(tax_household.primary, true),
    #     spouse: build_tax_member(tax_household.spouse), 
    #     dependents: tax_household.dependents.map{ |dependent| build_tax_member(dependent) },
    #     policy_ids: tax_household.coverage_as_of(Date.new(2014, month, 1))
    #   })
    # end

  
    # Implement for SHOP  
    def build_employer_mec(employer)
    end

    private

    def get_valid_policies(policy_ids)
      pols = policy_ids.inject([]) {|pols, id| pols << Policy.find(id)}
      pols.reject!{|pol| pol.rejected?}
      pols.reject!{|pol| pol.has_no_enrollees?}
      pols.reject!{|pol| !pol.belong_to_year?(@calender_year) }
      pols
    end

    def format_date(date)
      return nil if date.blank?
      date.strftime("%m/%d/%Y")
    end
  end
end

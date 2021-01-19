class TaxHousehold
  include Mongoid::Document
  include Mongoid::Timestamps
  include HasFamilyMembers

  # A set of family_members, grouped according to IRS and ACA rules, who are considered a single unit
  # when determining eligibility for Insurance Assistance and Medicaid

  embedded_in :household

  auto_increment :hbx_assigned_id, seed: 9999  # Create 'friendly' ID to publish for other systems

  field :allocated_aptc_in_cents, type: Integer, default: 0
  field :is_eligibility_determined, type: Boolean, default: false

  field :effective_start_date, type: Date
  field :effective_end_date, type: Date
  field :submitted_at, type: DateTime
  field :primary_applicant_id, type: Moped::BSON::ObjectId

  index({hbx_assigned_id: 1})

  embeds_many :tax_household_members
  accepts_nested_attributes_for :tax_household_members

  embeds_many :eligibility_determinations

  # *IMP* Check for tax members with financial information missing
  def members_with_financials
    tax_household_members.reject{|m| m.financial_statements.empty? }
  end

  def build_tax_family
    family = {}
    family[:primary] = primary
    family[:spouse] = spouse
    family[:dependents] = dependents
  end

  def associated_policies
    policies = []

    household.hbx_enrollments.each do |enrollment|
      if pol.subscriber.coverage_start > Date.new((date.year - 1),12,31) && pol.subscriber.coverage_start < Date.new(date.year,12,31)
        policy_disposition = PolicyDisposition.new(pol)
        coverages << pol if (policy_disposition.start_date.month..policy_disposition.end_date.month).include?(date.month)
      end
    end
    policies
  end

  def tax_dependents
    members_with_financials.select{ |m| m.financial_statements[0].tax_filing_status != 'tax_filer' }
  end

  def no_tax_filer?
    members_with_financials.detect{|m| m.financial_statements[0].tax_filing_status == 'tax_filer' }.nil?
  end

  def tax_filers
    members_with_financials.select{ |m| m.financial_statements[0].tax_filing_status == 'tax_filer' }
  end

  def primary
    return tax_household_members.first unless tax_household_members.count > 1
    return tax_filers.first unless tax_filers.count > 1
    tax_filer = tax_filers.detect{|filer| filer.is_primary_applicant? }
    return nil unless tax_filer
    tax_filer
  end

  # if tax_filers.detect{|filer| filer.financial_statements[0].is_tax_filing_together == false }
  #   raise 'multiple tax filers filing seperate in a single tax household!!'
  # end

  def spouse
    if tax_filers.count > 1
      return tax_filers.detect{|filer| !filer.is_primary_applicant? }
    else
      non_filers = members_with_financials.select{|m| m.financial_statements[0].tax_filing_status == 'non_filer'}
      if non_filers.any?
        non_filers.each do |non_filer|
          if has_spouse_relation?(non_filer)
            return non_filer
          end
        end
      end
    end
    nil
  end

  def has_spouse_relation?(non_filer)
    pols = non_filer.family_member.person.policies
    person = non_filer.family_member.person

    pols.each do |pol|
      member = pol.enrollees.detect{|enrollee| enrollee.person == person}
      if member.rel_code == 'spouse'
        return true
      end
    end
    false
  end

  def dependents
    members_with_financials.select {|m| 
      m.financial_statements[0].tax_filing_status == 'dependent'
    } + members_with_financials.select {|m| 
      m.financial_statements[0].tax_filing_status == 'non_filer'
    }.reject{|m| m == spouse || m == primary}
  end

  def coverage_policies(year)
    # if household.tax_households.count == 1
    #   household.enrollments_for_year(year).map(&:policy) 
    # else
      pols = []
      members_with_financials.each { |m|
        pols += m.family_member.person.policies
      }
      household.enrollments_for_year(year).map(&:policy) & pols
    # end
  end

  def self.filter_duplicates(tax_households)
    tax_households_by_primary = tax_households.inject({}) do |data, tax_household|
      (data["#{tax_household.primary.family_member}--#{tax_household.tax_household_members.count}"] ||= []) << tax_household
      data     
    end

    tax_households_by_primary.inject([]) {|data, (primary, tax_households)| data << tax_households[0]}
  end

  # def coverage_as_of(date)
  #   # pols = []
  #   # members_with_financials.select{|m|
  #   #    pols += m.family_member.person.policies
  #   # }
  #   pols = household.hbx_enrollments.select{|x| x.policy }
  #   coverages = []
  #   pols.uniq.select do |pol|
  #     if pol.subscriber.coverage_start > Date.new((date.year - 1),12,31) && pol.subscriber.coverage_start < Date.new(date.year,12,31)
  #       policy_disposition = PolicyDisposition.new(pol)
  #       coverages << pol if (policy_disposition.start_date.month..policy_disposition.end_date.month).include?(date.month)
  #     end
  #   end

  #   coverages.map{|x| x.id}
  # end

  def allocated_aptc_in_dollars=(dollars)
    self.allocated_aptc_in_cents = (Rational(dollars) * Rational(100)).to_i
  end

  def allocated_aptc_in_dollars
    (Rational(allocated_aptc_in_cents) / Rational(100)).to_f if allocated_aptc_in_cents
  end

  # Income sum of all tax filers in this Household for specified year
  def total_incomes_by_year
    family_member_links.inject({}) do |acc, per|
      p_incomes = per.financial_statements.inject({}) do |acc, ae|
        acc.merge(ae.total_incomes_by_year) { |k, ov, nv| ov + nv }
      end
      acc.merge(p_incomes) { |k, ov, nv| ov + nv }
    end
  end

  #TODO: return count for adults (21-64), children (<21) and total
  def size
    members.size 
  end

  def family
    return if household.blank?
    household.family
  end

  def is_eligibility_determined?
    elegibility_determinizations.size > 0 ? true : false
  end

  #primary applicant is the tax household member who is the subscriber
  def primary_applicant
    tax_household_members.detect do |tax_household_member| 
      tax_household_member.is_subscriber == true
    end
  end
end

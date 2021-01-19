class Household
  include Mongoid::Document
  include Mongoid::Timestamps
  include HasFamilyMembers

  embedded_in :family

  before_validation :set_effective_start_date
  before_validation :set_effective_end_date #, :if => lambda {|household| household.effective_end_date.blank? } # set_effective_start_date should be done before this
  before_validation :reset_is_active_for_previous
  before_validation :set_submitted_at #, :if => lambda {|household| household.submitted_at.blank? }

  # field :e_pdc_id, type: String  # Eligibility system PDC foreign key

  # embedded belongs_to :irs_group association
  field :irs_group_id, type: Moped::BSON::ObjectId

  field :is_active, type: Boolean, default: true
  field :effective_start_date, type: Date
  field :effective_end_date, type: Date

  field :submitted_at, type: DateTime

  embeds_many :hbx_enrollments
  accepts_nested_attributes_for :hbx_enrollments
  
  embeds_many :tax_households
  accepts_nested_attributes_for :tax_households
  
  embeds_many :coverage_households
  accepts_nested_attributes_for :coverage_households

  embeds_many :comments
  accepts_nested_attributes_for :comments, reject_if: proc { |attribs| attribs['content'].blank? }, allow_destroy: true

  validates :effective_start_date, presence: true

  validate :effective_end_date_gt_effective_start_date

  def effective_end_date_gt_effective_start_date

    return if parent.households.length < 2
    return if effective_end_date.nil?
    return if effective_start_date.nil?

    if effective_end_date < effective_start_date
      self.errors.add(:base, "The effective end date should be earlier or equal to effective start date")
    end
  end

  def parent
    raise "undefined parent family" unless self.family
    self.family
  end

  def irs_group=(irs_instance)
    return unless irs_instance.is_a? IrsGroup
    self.irs_group_id = irs_instance._id
  end

  def irs_group
    return nil if self.irs_group_id.nil?
    parent.irs_groups.find(self.irs_group_id)
  end

  def is_active?
    self.is_active
  end

  def latest_coverage_household
    return coverage_households.first if coverage_households.size = 1
    coverage_households.sort_by(&:submitted_at).last.submitted_at
  end

  def family_member_ids
    th_family_member_ids = tax_households.inject([]) do |acc, th|
      acc + th.family_member_ids
    end
    ch_family_member_ids = coverage_households.inject([]) do |acc, ch|
      acc + ch.family_member_ids
    end
    hbxe_family_member_ids = hbx_enrollments.inject([]) do |acc, he|
      acc + he.family_member_ids
    end
    (th_family_member_ids + ch_family_member_ids + hbxe_family_member_ids).distinct
  end

  # This will set the effective_end_date of previously active household to 1 day
  # before start of the current household's effective_start_date
  def set_effective_end_date
    return true unless self.effective_start_date

    latest_household = self.family.latest_household
    return true if self == latest_household

    latest_household.effective_end_date = self.effective_start_date - 1.day
    true
  end

  def reset_is_active_for_previous
    latest_household = self.family.latest_household
    active_value = self.is_active
    latest_household.is_active = false
    self.is_active = active_value
    true
  end

  def set_submitted_at
    return true unless self.submitted_at.blank?

    self.submitted_at = tax_households.sort_by(&:updated_at).last.updated_at if tax_households.length > 0
    self.submitted_at = parent.submitted_at unless self.submitted_at
    true
  end

  def set_effective_start_date
    return true unless self.effective_start_date.blank?

    self.effective_start_date =  parent.submitted_at
    true
  end

  def policy_coverage_households(year)
    policies_by_subscriber = enrollments_for_year(year).inject({}) do |hash, enrollment|
      person = enrollment.policy.subscriber.person
      (hash[person] ||= []) << enrollment.policy_id
      hash
    end

    policies_by_subscriber.inject([]) do |data, (person, policies)|
      data << {
        primary: person,
        policy_ids: policies
      }
    end
  end

  def enrollments_for_year(year)
    hbx_enrollments.select do  |enrollment| 
      valid_policy?(enrollment.policy) && enrollment.policy.belong_to_year?(year) && enrollment.policy.belong_to_authority_member?
    end
  end

  def has_aptc?(year)
    enrollments_for_year(year).map(&:policy).detect{|x| x.applied_aptc.to_f > 0 }.nil? ? false : true
  end

  def valid_policy?(pol)
    # return false if pol.rejected? || pol.has_no_enrollees? || pol.canceled? || pol.is_shop? || pol.terminated? # RENEWALS
    return false if pol.is_shop? || pol.rejected? || pol.has_no_enrollees? || pol.canceled?
    # if pol.plan.coverage_type =~ /health/i && pol.plan.hios_plan_id.match(/-01/).blank?
    #   puts "---found csr policy #{pol.id}"
    #   return false
    # end

    # Comment out following checks for RENEWALS
    return false unless pol.plan.coverage_type =~ /health/i
    return false if pol.plan.metal_level =~ /catastrophic/i

    true
  end
end

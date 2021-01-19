class Enrollee
  include Mongoid::Document
  include Mongoid::Timestamps

  BENEFIT_STATUS_CODE_LIST      = ["active", "cobra", "surviving insured", "tefra"]
  EMPLOYMENT_STATUS_CODE_LIST   = ["active", "full-time", "part-time", "retired", "terminated"]
  RELATIONSHIP_STATUS_CODE_LIST = ["self", "spouse", "child", "ward", "life partner"]

  RELATIONSHIP_CODE_MAP = {
    "self" => "self",
    "child" => "child",
    "spouse" => "spouse",
    "ward" => "ward",
    "life_partner" => "spouse",
    "domestic_partner" => "spouse",
    "adopted_child" => "child"
  }

  include MergingModel

  attr_accessor :include_checked

  field :m_id, as: :hbx_member_id, type: String

  field :ds, as: :disabled_status, type: Boolean, default: false
  field :ben_stat, as: :benefit_status_code, type: String, default: "active"
  field :emp_stat, as: :employment_status_code, type: String, default: "active"
  field :rel_code, as: :relationship_status_code, type: String

  field :c_id, as: :carrier_member_id, type: String
  field :cp_id, as: :carrier_policy_id, type: String
  field :pre_amt, as: :premium_amount, type: BigDecimal
  field :coverage_start, type: Date
  field :coverage_end, type: Date
  field :coverage_status, type: String, default: "active"

  embedded_in :policy, :inverse_of => :enrollees

  validates_presence_of :m_id, :relationship_status_code

  validates_inclusion_of :benefit_status_code, in: BENEFIT_STATUS_CODE_LIST
  validates_inclusion_of :employment_status_code, in: EMPLOYMENT_STATUS_CODE_LIST
  validates_inclusion_of :relationship_status_code, in: RELATIONSHIP_STATUS_CODE_LIST

  def self.map_relationship_code(relationship_code)
    RELATIONSHIP_CODE_MAP[relationship_code] || "child"
  end

  def coverage_start_matches?(date)
    if date.kind_of?(String)
      self.coverage_start == Date.parse(date)
    else
      self.coverage_start == date
    end
  end

  def person
    Queries::PersonByHbxIdQuery.new(m_id).execute
  end

  def member
    Queries::MemberByHbxIdQuery.new(m_id).execute
  end

  def calculate_premium_using(plan, rate_start_date)
    self.pre_amt = sprintf("%.2f", plan.rate(rate_start_date, self.coverage_start, self.member.dob).amount)
  end

  def merge_enrollee(m_enrollee, p_action)
    merge_without_blanking(
      m_enrollee,
      :pre_amt,
      :c_id,
      :cp_id,
      :coverage_start,
      :coverage_end,
      :ben_stat,
      :rel_code,
      :emp_stat,
      :ds
    )
    apply_policy_action(p_action)
  end

  def apply_policy_action(action)
    case action
    when :add
      self.coverage_status = 'active'
      self.coverage_end = nil
      if subscriber?
        self.policy.aasm_state = "submitted"
      end
    when :reinstate
      self.coverage_status = 'active'
      self.coverage_end = nil
      self.policy.aasm_state = "resubmitted"
    when :stop
      self.coverage_status = 'inactive'
      if subscriber?
        if self.coverage_start == self.coverage_end
          self.policy.aasm_state = "canceled"
        else
          self.policy.aasm_state = "terminated"
        end
      end
    else
    end
    self.save!
  end

  def clone_for_renewal(start_date)
    attrs = self.attributes.dup
    attrs.delete(:_id)
    attrs.delete("_id")
    attrs.delete(:id)
    attrs.delete("id")
    Enrollee.new(
      attrs.merge({
        :coverage_start => start_date,
        :coverage_end => nil,
        :pre_amt => nil,
        :coverage_status => "active",
        :c_id => nil,
        :cp_id => nil,
        :ben_stat => "active",
        :emp_stat => "active",
        :created_at => nil,
        :updated_at => nil
      })
    )
  end

  def active?
    self.coverage_status == 'active'
  end

  def canceled?
    return false unless coverage_ended?
    (self.coverage_start >= self.coverage_end)
  end

  def terminated?
    return false unless coverage_ended?
    (self.coverage_start < self.coverage_end)
  end

  def subscriber?
    self.relationship_status_code == "self"
  end

  def reference_premium_for(plan, rate_date)
    plan.rate(rate_date, coverage_start, member.dob).amount
  end

  def coverage_ended?
    !coverage_end.blank?
  end
end

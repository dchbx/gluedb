class Policy
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Versioning
#  include Mongoid::Paranoia
  include AASM

  extend Mongorder
  include MoneyMath

  attr_accessor :coverage_start

  Kinds = %w(individual employer_sponsored employer_sponsored_cobra coverall unassisted_qhp insurance_assisted_qhp streamlined_medicaid emergency_medicaid hcr_chip)
  ENROLLMENT_KINDS = %w(open_enrollment special_enrollment)

  auto_increment :_id

  field :eg_id, as: :enrollment_group_id, type: String
  field :preceding_enrollment_group_id, type: String
#  field :r_id, as: :hbx_responsible_party_id, type: String

  field :allocated_aptc, type: BigDecimal, default: 0.00
  field :elected_aptc, type: BigDecimal, default: 0.00
  field :applied_aptc, type: BigDecimal, default: 0.00
  field :csr_amt, type: BigDecimal

  field :pre_amt_tot, as: :total_premium_amount, type: BigDecimal, default: 0.00
  field :tot_res_amt, as: :total_responsible_amount, type: BigDecimal, default: 0.00
  field :tot_emp_res_amt, as: :employer_contribution, type: BigDecimal, default: 0.00
  field :sep_reason, type: String, default: :open_enrollment
  # Carrier to bill is always set to true for individual. Only Displays on _policy_detail.html.erb for IVL
  field :carrier_to_bill, type: Boolean, default: true
  field :aasm_state, type: String
  field :updated_by, type: String
  field :is_active, type: Boolean, default: true
  field :hbx_enrollment_ids, type: Array
  field :kind, type: String

# Adding field values Carrier specific
  field :carrier_specific_plan_id, type: String
  field :rating_area, type: String
  field :composite_rating_tier, type: String
  field :cobra_eligibility_date, type: Date

  # Enrollment data for federal reporting to mirror some of Enroll's
  field :kind, type: String
  field :enrollment_kind, type: String

  # flag for termination of policy due to non-payment
  field :term_for_np, type: Boolean, default: false

  validates_presence_of :eg_id
  validates_presence_of :pre_amt_tot
  validates_presence_of :tot_res_amt
  validates_presence_of :plan_id

  embeds_many :aptc_credits
  embeds_many :aptc_maximums

  embeds_many :cost_sharing_variants
  embeds_many :federal_transmissions

  embeds_many :enrollees
  accepts_nested_attributes_for :enrollees, reject_if: :all_blank, allow_destroy: true

  embeds_many :comments
  accepts_nested_attributes_for :comments, reject_if: proc { |attribs| attribs['content'].blank? }, allow_destroy: true

  belongs_to :hbx_enrollment_policy, class_name: "Family", inverse_of: :hbx_enrollment_policies, index: true
  belongs_to :carrier, counter_cache: true, index: true
  belongs_to :broker, counter_cache: true, index: true # Assumes that broker change triggers new enrollment group
  belongs_to :plan, counter_cache: true, index: true
  belongs_to :employer, counter_cache: true, index: true
  belongs_to :responsible_party

  has_many :legacy_cv_transactions,
            class_name: "Protocols::LegacyCv::LegacyCvTransaction",
            order: { submitted_at: :desc }

  has_many :transaction_set_enrollments,
              class_name: "Protocols::X12::TransactionSetEnrollment",
              order: { submitted_at: :desc }
  has_many :premium_payments, order: { paid_at: 1 }

  has_many :csv_transactions, :class_name => "Protocols::Csv::CsvTransaction"

  index({:hbx_enrollment_ids => 1})
  index({:eg_id => 1})
  index({:aasm_state => 1})
  index({:eg_id => 1, :carrier_id => 1, :plan_id => 1})
  index({ "enrollees.person_id" => 1 })
  index({ "enrollees.m_id" => 1 })
  index({ "enrollees.hbx_member_id" => 1 })
  index({ "enrollees.carrier_member_id" => 1})
  index({ "enrollees.carrier_policy_id" => 1})
  index({ "enrollees.rel_code" => 1})
  index({ "enrollees.coverage_start" => 1})
  index({ "enrollees.coverage_end" => 1})

  before_create :generate_enrollment_group_id
  before_save :invalidate_find_cache
  before_save :check_for_cancel_or_term
  before_save :check_multi_aptc
  after_save :cancel_ivl_renewal

  scope :all_active_states,   where(:aasm_state.in => %w[submitted resubmitted effectuated])
  scope :all_inactive_states, where(:aasm_state.in => %w[canceled carrier_canceled terminated])

  scope :individual_market, where(:employer_id => nil)
  scope :unassisted, where(:applied_aptc.in => ["0", "0.0", "0.00"])
    scope :insurance_assisted, where(:applied_aptc.nin => ["0", "0.0", "0.00"])

  # scopes of renewal reports
  scope :active_renewal_policies, where({:employer_id => nil, :enrollees => {"$elemMatch" => { :rel_code => "self", :coverage_start => {"$gt" => Date.new(2014,12,31)}, :coverage_end.in => [nil]}}})
  scope :by_member_id, ->(member_id) { where("enrollees.m_id" => {"$in" => [ member_id ]}, "enrollees.rel_code" => "self") }
  scope :with_aptc, where(PolicyQueries.with_aptc)
  scope :without_aptc, where(PolicyQueries.without_aptc)

  aasm do
    state :submitted, initial: true
    state :effectuated
    state :carrier_canceled
    state :carrier_terminated
    state :hbx_canceled
    state :hbx_terminated

    event :initial_enrollment do
      transitions from: :submitted, to: :submitted
    end

    event :effectuate do
      transitions from: :submitted, to: :effectuated
      transitions from: :effectuated, to: :effectuated
      transitions from: :hbx_canceled, to: :hbx_canceled
      transitions from: :hbx_terminated, to: :hbx_terminated
    end

    event :carrier_cancel do
      transitions from: :submitted, to: :carrier_canceled
      transitions from: :carrier_canceled, to: :carrier_canceled
      transitions from: :carrier_terminated, to: :carrier_canceled
      transitions from: :hbx_canceled, to: :hbx_canceled
      transitions from: :hbx_terminated, to: :carrier_canceled
    end

    event :carrier_terminate do
      transitions from: :submitted, to: :carrier_terminated
      transitions from: :effectuated, to: :carrier_terminated
      transitions from: :carrier_terminated, to: :carrier_terminated
      transitions from: :hbx_terminated, to: :hbx_terminated
    end

    event :hbx_cancel do
      transitions from: :submitted, to: :hbx_canceled
      transitions from: :effectuated, to: :hbx_canceled
      transitions from: :carrier_canceled, to: :hbx_canceled
      transitions from: :carrier_terminated, to: :hbx_canceled
      transitions from: :hbx_canceled, to: :hbx_canceled
      transitions from: :hbx_terminated, to: :hbx_canceled
    end

    event :hbx_terminate do
      transitions from: :submitted, to: :hbx_terminated
      transitions from: :effectuated, to: :hbx_terminated
      transitions from: :carrier_terminated, to: :carrier_terminated
      transitions from: :carrier_canceled, to: :hbx_terminated
      transitions from: :hbx_terminated, to: :hbx_terminated
    end

    event :hbx_reinstate do
      transitions from: :carrier_terminated, to: :submitted
      transitions from: :carrier_canceled, to: :submitted
      transitions from: :hbx_terminated, to: :submitted
      transitions from: :hbx_canceled, to: :submitted
    end

    # Carrier Attestation documentation reference should accompany this non-standard transition
    event :carrier_reinstate do
      transitions from: :carrier_terminated, to: :effectuated
      transitions from: :carrier_canceled, to: :effectuated
    end
  end

  def self.default_search_order
    [
      ["members.coverage_start", 1]
    ]
  end

  def calculated_premium_effective_date
    subscriber_start = subscriber.coverage_start
    non_canceled_enrollees = enrollees.reject do |en|
      en.coverage_ended? && (en.coverage_end <= en.coverage_start)
    end
    # Return the enrollment start if everybody is canceled
    return subscriber_start if non_canceled_enrollees.empty?
    latest_possible_date = subscriber.coverage_ended? ? subscriber.coverage_end : coverage_year.end
    # Discard end dates that are the last possible policy day,
    # Since we are going to pick up one day after
    latest_end_dates = non_canceled_enrollees.map(&:coverage_end).compact.reject do |d|
      d >= latest_possible_date
    end
    # The last day of coverage +1 day is actually the
    # date the premium for somebody terminated becomes effected
    provided_end_dates = latest_end_dates.map do |d|
      d + 1.day
    end
    latest_start_dates = non_canceled_enrollees.map(&:coverage_start).compact
    (provided_end_dates + latest_start_dates).max
  end

  def effectuated?
    edi_transactions = edi_transaction_sets
    edi_transactions.any?{|transaction| transaction.transaction_kind == 'effectuation'}
  end

  def canceled?
    subscriber.canceled?
  end

  def terminated?
    subscriber.terminated?
  end

  def market
    is_shop? ? 'shop' : 'individual'
  end

  def is_shop?
    !employer_id.blank?
  end

  def subscriber
    enrollees.detect { |m| m.relationship_status_code == "self" }
  end

  def is_cobra?
    cobra_eligibility_date.present? || enrollees.any? { |en| en.ben_stat == "cobra"}
  end

  def spouse
    enrollees.detect { |m| m.relationship_status_code == "spouse" && !m.canceled? }
  end

  def enrollees_sans_subscriber
    enrollees.reject { |e| e.relationship_status_code == "self" }
  end

  def dependents
    enrollees.reject { |e| e.canceled? || e.relationship_status_code == "self" ||  e.relationship_status_code == "spouse" }
  end

  def has_responsible_person?
    !self.responsible_party_id.blank?
  end

  def active_member_ids
    enrollees.reject { |e| e.canceled? || e.terminated? }.map(&:m_id)
  end

  def responsible_person
    query_proxy.responsible_person
  end

  def people
    query_proxy.people
  end

  def merge_enrollee(m_enrollee, p_action)
    found_enrollee = self.enrollees.detect do |enr|
      enr.m_id == m_enrollee.m_id
    end
    if found_enrollee.nil?
      if p_action == :stop
        m_enrollee.coverage_status = 'inactive'
      end
      self.enrollees << m_enrollee
    else
      found_enrollee.merge_enrollee(m_enrollee, p_action)
      found_enrollee.touch
      self.touch
      self.save!
    end
  end

  def latest_transaction_date
    (transaction_set_enrollments + csv_transactions).sort_by(&:submitted_at).last.submitted_at
  end

  def edi_transaction_sets
    Protocols::X12::TransactionSetEnrollment.where({"policy_id" => self._id})
  end

  def invalidate_find_cache
    Rails.cache.delete("Policy/find/subkeys.#{enrollment_group_id}.#{carrier_id}.#{plan_id}")
    if !subscriber.nil?
      Rails.cache.delete("Policy/find/sub_plan.#{subscriber.m_id}.#{plan_id}")
    end
    true
  end

  def hios_plan_id
    self.plan.hios_plan_id
  end

  def coverage_type
    self.plan.coverage_type
  end

  def enrollee_for_member_id(m_id)
    self.enrollees.detect { |en| en.m_id == m_id }
  end

  def to_cv
    CanonicalVocabulary::EnrollmentSerializer.new(self, member_ids).serialize
  end

  def self.find_all_policies_for_member_id(m_id)
    self.where(
      "enrollees.m_id" => m_id
    ).order_by([:eg_id])
  end

  def self.search_hash(s_str)
    clean_str = s_str.strip
    s_rex = Regexp.new(Regexp.escape(clean_str), true)
    {
      "$or" => [
        {"eg_id" => s_rex},
        {"id" => s_rex.source},
        {"enrollees.m_id" => s_rex}
      ]
    }
  end

  def self.find_by_sub_and_plan(sub_id, h_id)
#    Rails.cache.fetch("Policy/find/sub_plan.#{sub_id}.#{h_id}") do
      plans = Plan.where(:hios_plan_id => h_id)
      found_policies = Policy.where(
        {
          :plan_id => {"$in" => plans.map(&:_id)},
          :enrollees => {
            "$elemMatch" => {
              :rel_code => "self",
              :m_id => sub_id
            }
          }
        })

      if found_policies.count > 1
        (found_policies.reject { |pol| pol.aasm_state == "canceled" }).first
      else
        found_policies.first
      end
#    end
  end

  def self.find_for_group_and_hios(eg_id, h_id)
      plans = Caches::HiosCache.lookup(h_id) { Plan.where(hios_plan_id: h_id) }
      plan_ids = plans.map(&:_id)

      policies = Policy.where(
        {
          :eg_id => eg_id,
          :plan_id => {
            '$in' => plan_ids
          }
        })
      if(policies.count > 1)
        raise "More than one policy that match subkeys: eg_id=#{eg_id}, plan_ids=#{plan_ids}"
      end
      policies.first
  end

  def self.find_by_subkeys(eg_id, c_id, h_id)
      plans = Plan.where(hios_plan_id: h_id)
      plan_ids = plans.map(&:_id)

      policies = Policy.where(
        {
          :eg_id => eg_id,
          :carrier_id => c_id,
          :plan_id => {
            '$in' => plan_ids
          }
        })
      if(policies.count > 1)
        raise "More than one policy that match subkeys: eg_id=#{eg_id}, carrier_id=#{c_id}, plan_ids=#{plan_ids}"
      end
      policies.first
  end

  def self.find_or_update_policy(m_enrollment)
    plan = Caches::MongoidCache.lookup(Plan, m_enrollment.plan_id) { Plan.find(m_enrollment.plan_id) }
    found_enrollment = self.find_by_subkeys(
      m_enrollment.enrollment_group_id,
      m_enrollment.carrier_id,
      plan.hios_plan_id
    )
    if found_enrollment
      found_enrollment.responsible_party_id = m_enrollment.responsible_party_id
      found_enrollment.employer_id = m_enrollment.employer_id
      found_enrollment.broker_id = m_enrollment.broker_id
      found_enrollment.applied_aptc = m_enrollment.applied_aptc
      found_enrollment.tot_res_amt = m_enrollment.tot_res_amt
      found_enrollment.pre_amt_tot = m_enrollment.pre_amt_tot
      found_enrollment.employer_contribution = m_enrollment.employer_contribution
      # Carrier to bill is always set to true for individual. Only Displays on _policy_detail.html.erb for IVL
      found_enrollment.carrier_to_bill = true
      found_enrollment.save!
      return found_enrollment
    end
    # Observers::PolicyUpdated.notify(m_enrollment) notified in calling method before save transmission_file.rb/persist_policy
    m_enrollment.save!
    #  m_enrollment.unsafe_save!
    m_enrollment
  end



  def check_for_cancel_or_term
    if !self.subscriber.nil?
      if self.subscriber.canceled?
        self.aasm_state = "canceled"
      elsif self.subscriber.terminated?
        self.aasm_state = "terminated"
      end
    end
    true
  end

  def unsafe_save!
    Policy.skip_callback(:save, :before, :revise)
    save(validate: false)
    Policy.set_callback(:save, :before, :revise)
  end

  def self.find_covered_in_range(start_d, end_d)
    Policy.where(
      :aasm_state => { "$ne" => "canceled"},
      :enrollees => {"$elemMatch" => {
          :rel_code => "self",
          :coverage_start => {"$lte" => end_d},
          "$or" => [
            {:coverage_end => {"$gt" => start_d}},
            {:coverage_end => {"$exists" => false}},
            {:coverage_end => nil}
          ]
        }
      }
    )
  end

  def self.find_active_and_unterminated_for_members_in_range(m_ids, start_d, end_d, other_params = {})
    Policy.where(
      PolicyStatus::Active.as_of(end_d).query).where(
      {"enrollees" => {
        "$elemMatch" => {
          "m_id" => { "$in" => m_ids },
          "coverage_start" => { "$lt" => end_d },
          "$or" => [
            {:coverage_end => {"$gt" => end_d}},
            {:coverage_end => {"$exists" => false}},
            {:coverage_end => nil}
          ]
        }
      } })

  end

  def self.find_active_and_unterminated_in_range(start_d, end_d, other_params = {})
    Policy.where(
      PolicyStatus::Active.as_of(end_d).query).where( other_params)
  end

  def self.find_terminated_in_range(start_d, end_d, other_params = {})
    Policy.where(
      PolicyStatus::Terminated.during(
        start_d,
        end_d
        ).query
    )
  end

  def self.process_audits(active_start, active_end, term_start, term_end, other_params, out_directory)
    ProcessAudits.execute(active_start, active_end, term_start, term_end, other_params, out_directory)
  end

  def can_edit_address?
    return(true) if members.length < 2
    members.map(&:person).combination(2).all? do |addr_set|
      addr_set.first.addresses_match?(addr_set.last)
    end
  end

  def coverage_start_for(member_id)
    member = enrollees.detect { |en| en.m_id == member_id }
    member ? member.coverage_start : nil
  end

  def self.active_as_of_expression(target_date)
    {
      "$or" => [
        { :aasm_state => { "$ne" => "canceled"},
          :eg_id => { "$not" => /DC0.{32}/ },
          :enrollees => {"$elemMatch" => {
            :rel_code => "self",
            :coverage_start => {"$lte" => target_date},
            :coverage_end => {"$gt" => target_date}
          }}},
          { :aasm_state => { "$ne" => "canceled"},
            :eg_id => { "$not" => /DC0.{32}/ },
            :enrollees => {"$elemMatch" => {
              :rel_code => "self",
              :coverage_start => {"$lte" => target_date},
              :coverage_end => {"$exists" => false}
            }}},
            { :aasm_state => { "$ne" => "canceled"},
              :eg_id => { "$not" => /DC0.{32}/ },
              :enrollees => {"$elemMatch" => {
                :rel_code => "self",
                :coverage_start => {"$lte" => target_date},
                :coverage_end => nil
              }}}
      ]
    }
  end

  def active_enrollees
    enrollees.select { |e| e.coverage_status == 'active' }
  end

  def currently_active?
    return false if subscriber.nil?
    return false if eg_id =~ /DC0.{32}/
    now = Date.today
    return false if subscriber.coverage_start > now
    return false if (subscriber.coverage_start == subscriber.coverage_end)
    return false if (!subscriber.coverage_end.nil? && subscriber.coverage_end < now)
    true
  end

  def active_and_renewal_eligible?
    return false if subscriber.nil?
    return false if eg_id =~ /DC0.{32}/
    # now = Date.today
    # return false if (subscriber.coverage_start == subscriber.coverage_end)
    # return false if (!subscriber.coverage_end.nil? && subscriber.coverage_end < now)
    return false if subscriber.coverage_start.nil? || subscriber.coverage_start >= Date.strptime("20150101",'%Y%m%d')
    return false if (!subscriber.coverage_end.nil? && subscriber.coverage_end < Date.strptime("20150101",'%Y%m%d'))
    true
  end

  def active_on_date_for?(date, member_id)
    return false unless active_as_of?(date)
    en = enrollees.detect { |enr| enr.m_id == member_id }
    return false if en.nil?
    return false if en.coverage_start > date
    return false if (en.coverage_start == en.coverage_end)
    return false if (!en.coverage_end.nil? && en.coverage_end < date)
    true
  end

  def currently_active_for?(member_id)
    now = Date.today
    active_on_date_for?(now, member_id)
  end

  def future_active?
    now = Date.today
    return false if subscriber.nil?
    return false if (subscriber.coverage_start == subscriber.coverage_end)
    return false if (!subscriber.coverage_end.nil? && subscriber.coverage_end < now)
    subscriber.coverage_start > now
  end

  def active_as_of?(date)
    return false if subscriber.nil?
    return false if (subscriber.coverage_start == subscriber.coverage_end)
    return false if (!subscriber.coverage_end.nil? && subscriber.coverage_end < date)
    coverage_period.include?(date)
  end

  def future_active_for?(member_id)
    en = enrollees.detect { |enr| enr.m_id == member_id }
    now = Date.today
    return false if en.nil?
    return false if (en.coverage_start == en.coverage_end)
    return false if (!en.coverage_end.nil? && en.coverage_end < now)
    return true if en.coverage_start > now
  end

  def policy_start
    subscriber.coverage_start
  end

  def policy_end
    subscriber.coverage_end
  end

  def self.find_by_id(the_id)
    Policy.where({:id => the_id}).first
  end

  def set_aptc_effective_on(aptc_date, aptc_amount, pre_total_amount, remaining_owed_by_consumer)
    if self.aptc_credits.empty?
      if aptc_date == policy_start
        self.aptc_credits << AptcCredit.new(
          start_on: aptc_date,
          end_on: coverage_period_end,
          pre_amt_tot: pre_total_amount,
          aptc: aptc_amount,
          tot_res_amt: remaining_owed_by_consumer
        )
      else
        self.aptc_credits << AptcCredit.new(
          start_on: policy_start,
          end_on: aptc_date - 1.day,
          pre_amt_tot: self.pre_amt_tot,
          aptc: self.applied_aptc,
          tot_res_amt: self.tot_res_amt
        )
        self.aptc_credits << AptcCredit.new(
          start_on: aptc_date,
          end_on: coverage_period_end,
          pre_amt_tot: pre_total_amount,
          aptc: aptc_amount,
          tot_res_amt: remaining_owed_by_consumer
        )
      end
    else
      aptc_record = self.aptc_record_on(aptc_date)
      if aptc_record.start_on == aptc_date
        aptc_record.update_attributes(
          pre_amt_tot: pre_total_amount,
          aptc: aptc_amount,
          tot_res_amt: remaining_owed_by_consumer
        )
      else
        aptc_record.update_attributes(
          end_on: (aptc_date - 1.day)
        )
        self.aptc_credits << AptcCredit.new(
          start_on: aptc_date,
          end_on: coverage_period_end,
          pre_amt_tot: pre_total_amount,
          aptc: aptc_amount,
          tot_res_amt: remaining_owed_by_consumer
        )
      end
    end
    self.pre_amt_tot = pre_total_amount
    self.tot_res_amt = remaining_owed_by_consumer
    self.applied_aptc = aptc_amount
  end

  def coverage_period
    start_date = policy_start

    if !policy_end.nil?
      # if policy_end.year > policy_start.year
      #   return (start_date..Date.new(start_date.year, 12, 31))
      # else
        return (start_date..policy_end)
      # end
    end

    if employer_id.blank?
       return (start_date..Date.new(start_date.year, 12, 31))
    end
    py = employer.plan_year_of(start_date)
    (start_date..py.end_date)
  end

  def coverage_year
      start_date = policy_start
      if employer_id.blank?
        return (Date.new(start_date.year, 1, 1)..Date.new(start_date.year, 12, 31))
      end
      py = employer.plan_year_of(start_date)
      (py.start_date..py.end_date)
  end

  def coverage_period_end
    coverage_period.end
  end

  def transaction_list
    (transaction_set_enrollments + csv_transactions).sort_by(&:submitted_at).reverse
  end

  def is_active?
    currently_active?
  end

  def terminate_as_of(term_date)
    self.aasm_state = "hbx_terminated"
    self.enrollees.each do |en|
      if en.coverage_end.blank? || (en.coverage_end.present? && (en.coverage_end > term_date))
        en.coverage_end = term_date
        en.coverage_end = en.coverage_start if term_date < en.coverage_start
        en.coverage_status = "inactive"
        en.employment_status_code = "terminated"
      end
    end
    self.save
  end

  def terminate_member_id_on(member_id, term_date)
    enrollee_to_term = self.enrollees.detect { |en| en.m_id == member_id }
    return true unless enrollee_to_term
    if enrollee_to_term.coverage_end.blank? || (!enrollee_to_term.coverage_end.blank? && (enrollee_to_term.coverage_end > term_date))
      enrollee_to_term.coverage_end = term_date
      enrollee_to_term.coverage_status = "inactive"
      enrollee_to_term.employment_status_code = "terminated"
    end
    self.save
  end

  def cancel_via_hbx!
    self.aasm_state = "hbx_canceled"
    self.enrollees.each do |en|
      en.coverage_end = en.coverage_start
      en.coverage_status = 'inactive'
      en.employment_status_code = 'terminated'
    end
    self.save!
  end

  def clone_for_renewal(start_date)
    pol = Policy.new({
      :broker => self.broker,
      :employer_id => self.employer_id,
      :carrier_to_bill => self.carrier_to_bill,
      :preceding_enrollment_group_id => self.eg_id,
      :carrier_id => self.carrier_id,
      :responsible_party_id => self.responsible_party_id
    })
    cloneable_enrollees = self.enrollees.reject do |en|
      en.canceled? || en.terminated?
    end
    enrollees = cloneable_enrollees.map do |en|
      en.clone_for_renewal(start_date)
    end
    pol.enrollees = enrollees

    current_plan = Caches::MongoidCache.lookup(Plan, self.plan_id) { self.plan }
    pol.plan = Caches::MongoidCache.lookup(Plan, current_plan.renewal_plan_id) { current_plan.renewal_plan }
    return pol
  end

  def ehb_premium
    return as_dollars(self.pre_amt_tot) if self.plan.ehb.to_f.zero?
    as_dollars(self.pre_amt_tot * self.plan.ehb)
  end

  def changes_over_time?
    return true if multi_aptc?
    eligible_enrollees = self.enrollees.reject do |en|
      en.canceled?
    end
    starts = eligible_enrollees.map(&:coverage_start).uniq
    return true if (starts.length > 1)
    end_dates = eligible_enrollees.map do |en|
      en.coverage_end.blank? ? self.coverage_period_end : en.coverage_end
    end
    end_dates.uniq.length > 1
  end

  def rejected?
    edi_transactions = Protocols::X12::TransactionSetEnrollment.where({ "policy_id" => self.id })
    (edi_transactions.count == 1 && edi_transactions.first.aasm_state == 'rejected') ? true : false
  end

  def has_no_enrollees?
    # active_enrollees = self.enrollees.reject{|en| en.canceled? || en.terminated? } # RENEWALS
    active_enrollees = self.enrollees.reject{|en| en.canceled?}
    active_enrollees.empty? ? true : false
  end

  def belong_to_year?(year)
    self.subscriber.coverage_start > Date.new((year - 1), 12, 31) && self.subscriber.coverage_start < Date.new(year, 12, 31)
  end

  def authority_member
    self.subscriber.person.authority_member
  end

  def belong_to_authority_member?
    authority_member.hbx_member_id == self.subscriber.m_id
  end

  def check_multi_aptc
    return true unless self.multi_aptc?
    if self.policy_end.present?
      latest_record = self.aptc_record_on(policy_end)
    else
      latest_record = self.latest_aptc_record
    end
    self.applied_aptc = latest_record.aptc
    self.pre_amt_tot = latest_record.pre_amt_tot
    self.tot_res_amt = latest_record.tot_res_amt
  end

  def reported_tot_res_amt_on(date)
    return self.tot_res_amt unless multi_aptc?
    return 0.0 unless self.aptc_record_on(date)
    self.aptc_record_on(date).tot_res_amt
  end

  def reported_pre_amt_tot_on(date)
    return self.pre_amt_tot unless multi_aptc?
    return 0.0 unless self.aptc_record_on(date)
    self.aptc_record_on(date).pre_amt_tot
  end

  def reported_aptc_on(date)
    return self.applied_aptc unless multi_aptc?
    return 0.0 unless self.aptc_record_on(date)
    self.aptc_record_on(date).aptc
  end

  def multi_aptc?
    self.aptc_credits.any?
  end

  def latest_aptc_record
    aptc_credits.sort_by { |aptc_rec| aptc_rec.start_on }.last
  end

  def aptc_record_on(date)
    self.aptc_credits.detect { |aptc_rec| aptc_rec.start_on <= date && aptc_rec.end_on >= date }
  end

  def assistance_effective_date
    if self.aptc_credits.present?
      self.latest_aptc_record.start_on
    else
      dates = self.enrollees.map(&:coverage_start) + self.enrollees.map(&:coverage_end)
      assistance_effective_date = dates.compact.sort.last
    end
  end

  def self.update_or_create_policy_from_edi(
      before_updated_policy = nil,
      update_policy_record,
      transmission_file_util,
      etf_loop,
      transaction_set_kind
    )
    updated_or_created_policy = Policy.find_or_update_policy(update_policy_record)
    if transaction_set_kind == "effectuation"
      updated_or_created_policy.aasm_state = 'effectuated'
    end

    etf_loop.people.each do |person_loop|
      policy_loop = person_loop.policy_loops.first
      enrollee = transmission_file_util.build_enrollee(person_loop, policy_loop)
      updated_or_created_policy.merge_enrollee(enrollee, policy_loop.action)
    end

    transaction_type =  etf_loop.people.inject([]) do |type, person_loop|
                          policy_loop = person_loop.policy_loops.first
                          type << policy_loop.action
                          type
                        end

    updated_or_created_policy.save!

    unless policy_eligible_to_notify?(updated_or_created_policy) #if true then we don't want to notify
      unless transaction_type.include?(:stop) && termination_event_exempt_from_notification?(before_updated_policy, updated_or_created_policy)
        Observers::PolicyUpdated.notify(updated_or_created_policy) #notify to generate H41's && 1095A's
      end
    end
    updated_or_created_policy
  end

  def self.termination_event_exempt_from_notification?(before_updated_policy, updated_policy)
    if before_updated_policy.present?
      #Policy End Date change - null to 12/31 AND no NPT indicator change (don't notify)
      #Dependent Only End Date Change - null to 12/31 AND no NPT status change (don't notify)
      if is_npt_flag_same?(before_updated_policy, updated_policy)
        is_enrollee_coverage_end_change_to_end_of_year?(before_updated_policy, updated_policy)
      else
        false #we notify
      end
    else
      false #we notify
    end
  end

  def self.policy_eligible_to_notify?(updated_policy)
    updated_policy.kind == 'coverall' || updated_policy.is_shop? || updated_policy.coverage_type.to_s.downcase != "health" || updated_policy.plan.metal_level == "catastrophic" || updated_policy.coverage_year.first.year == Time.now.year || updated_policy.coverage_year.first.year < 2018
  end

  def self.is_npt_flag_same?(before_updated_policy, updated_policy)
    before_updated_policy.term_for_np == updated_policy.term_for_np
  end

  def self.is_enrollee_coverage_end_change_to_end_of_year?(before_updated_policy, updated_policy)
    updated_policy.enrollees.each do |updated_enrollee|
      before_updated_policy.enrollees.each do |before_updated_enrollee|
        next if updated_enrollee.id != before_updated_enrollee.id

        if check_enrollee_coverage_end?(updated_enrollee)
          unless before_updated_enrollee.coverage_end.nil?
            unless before_updated_enrollee.coverage_end == updated_enrollee.coverage_end
              return false #we notify
            end
          end
        else
          if updated_enrollee.coverage_end.present? && before_updated_enrollee.coverage_end.nil?
            return  false #we notify
          else
            unless before_updated_enrollee.coverage_end == updated_enrollee.coverage_end
              return false  #we notify
            end
          end
        end
      end
    end
    true #we don't notify
  end

  def self.check_enrollee_coverage_end?(updated_enrollee)
    (updated_enrollee.coverage_end.try(:day) == 31) && (updated_enrollee.coverage_end.try(:month) == 12)
  end

  def cancel_ivl_renewal
    if subscriber.present? && (terminated? || canceled?) && carrier && carrier.termination_cancels_renewal
      matched_ivl_renewals.each do |pol|
        pol.cancel_via_hbx!
      end
    end
  end

  def matched_ivl_renewals
    subscriber_person = subscriber.person
    subscriber_person.policies.select do |pol|
      is_ivl_renewal_policy?(pol)
    end
  end

  def is_ivl_renewal_policy?(pol)
    return false if pol.id == id
    return false if pol.is_shop?
    return false if pol.canceled?
    return false if pol.terminated?
    return false if pol.subscriber.blank?
    return false if pol.subscriber.m_id != subscriber.m_id
    return false if pol.plan.blank?
    return false unless plan.carrier_id == pol.plan.carrier_id
    return false unless plan.coverage_type == pol.plan.coverage_type
    return false unless plan.year + 1 == pol.plan.year
    return false unless plan_matched?(plan, pol.plan)
    return false unless pol.active_member_ids.all? { |m_id| enrollees.map(&:m_id).include?(m_id)}
    return false if pol.subscriber.coverage_end.present?
    pol.subscriber.coverage_start == coverage_year.end + 1
  end

  def plan_matched?(active_plan, renewal_plan)
    if active_plan.metal_level == "catastrophic" && active_plan.coverage_type == "health"
      ['94506DC0390008','86052DC0400004'].include?(active_plan.hios_plan_id.split("-").first) &&
          (['94506DC0390010','86052DC0400010'].include?(renewal_plan.hios_plan_id.split("-").first) || active_plan.renewal_plan == renewal_plan)
    else
      (active_plan.renewal_plan == renewal_plan || active_plan.renewal_plan.hios_plan_id.split("-").first == renewal_plan.hios_plan_id.split("-").first)
    end
  end

  protected
  def generate_enrollment_group_id
    self.eg_id = self.eg_id || self._id.to_s
    self.hbx_enrollment_ids = [self.eg_id]
  end

  private
  def format_money(val)
    sprintf("%.02f", val)
  end

  def filter_delimiters(str)
    str.to_s.gsub(',','') if str.present?
  end

  def filter_non_numbers(str)
    str.to_s.gsub(/\D/,'') if str.present?
  end

  def query_proxy
    @query_proxy ||= Queries::PolicyAssociations.new(self)
  end

  def member_ids
    self.enrollees.map do |enrollee|
      enrollee.m_id
    end
  end
end

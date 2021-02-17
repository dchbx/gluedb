module ExternalEvents
  class ExternalPolicyMemberDrop
    attr_reader :policy_node
    attr_reader :dropped_member_ids
    attr_reader :policy_to_update
    attr_reader :total_source

    include Handlers::EnrollmentEventXmlHelper
    include ::EnrollmentAction::NotificationExemptionHelper

    # p_node : Openhbx::Cv2::Policy
    def initialize(pol_to_change, p_node, d_member_ids)
      @policy_node = p_node
      @dropped_member_ids = d_member_ids
      @policy_to_update = pol_to_change
      @total_source = p_node
    end

    # Assign totals from another event.  This is used in the rare case where
    # we want to update glue with the totals from one XML, but otherwise
    # use the data from another. (Really only occurs in the dependent drop
    # scenario)
    def use_totals_from(other_policy_cv)
      @total_source = other_policy_cv
    end

    def extract_pre_amt_tot
      @pre_amt_tot_val ||= begin
                             p_enrollment = Maybe.new(@total_source).policy_enrollment.value
                             p_enrollment.blank? ? 0.00 : BigDecimal.new(Maybe.new(p_enrollment).premium_total_amount.strip.value)
                           end
    end

    def extract_tot_res_amt
      @tot_res_amt_val ||= begin
                             p_enrollment = Maybe.new(@total_source).policy_enrollment.value
                             p_enrollment.blank? ? 0.00 : BigDecimal.new(Maybe.new(p_enrollment).total_responsible_amount.strip.value)
                           end
    end

    def extract_aptc_amount
      @aptc_amt_val ||= begin
                          p_enrollment = Maybe.new(@total_source).policy_enrollment.value
                          applied_aptc_val = Maybe.new(p_enrollment).individual_market.applied_aptc_amount.strip.value
                          applied_aptc_val.blank? ? nil : BigDecimal.new(applied_aptc_val)
                        end
    end

    def extract_employer_contribution
      @tot_emp_res_amt_val ||= begin
                                 tot_emp_res_amt = Maybe.new(@total_source).policy_enrollment.shop_market.total_employer_responsible_amount.strip.value
                                 tot_emp_res_amt.blank? ? nil : BigDecimal.new(tot_emp_res_amt)
                               end
    end

    def extract_enrollee_premium(enrollee)
      enrollee_in_source = lookup_enrollee_in_total_source(enrollee)
      enrollee_in_source.blank? ? enrollee_money_from_node(enrollee) : enrollee_money_from_node(enrollee_in_source)
    end

    def lookup_enrollee_in_total_source(enrollee)
      en_list = Maybe.new(@total_source).enrollees.value
      return nil if en_list.blank?
      en_list.detect do |enrollee_node|
        enrollee_member_id = Maybe.new(enrollee).member.id.value
        enrollee_node_member_id = Maybe.new(enrollee_node).member.id.value
        (!enrollee_member_id.blank?) && (enrollee_member_id == enrollee_node_member_id)
      end
    end

    def enrollee_money_from_node(enrollee)
      pre_string = Maybe.new(enrollee).benefit.premium_amount.value
      return 0.00 if pre_string.blank?
      BigDecimal.new(pre_string)
    end

    def extract_other_financials
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return({}) if p_enrollment.blank?
      if p_enrollment.shop_market
        tot_emp_res_amt = extract_employer_contribution
        employer = find_employer(@policy_node)
        return({ :employer => employer }) if tot_emp_res_amt.blank?
        {
          :employer => employer,
          :tot_emp_res_amt => tot_emp_res_amt
        }
      else
        aptc_val = extract_aptc_amount
        return({}) if aptc_val.blank?
        {
          :applied_aptc => aptc_val
        }
      end
    end

    def extract_rel_from_me(rel)
      simple_relationship = Maybe.new(rel).relationship_uri.strip.split("#").last.downcase.value
      case simple_relationship
      when "spouse", "life_partner", "domestic_partner"
        "spouse"
      when "ward"
        "ward"
      else
        "child"
      end
    end

    def extract_rel_from_sub(rel)
      simple_relationship = Maybe.new(rel).relationship_uri.strip.split("#").last.downcase.value
      case simple_relationship
      when "spouse", "life_partner", "domestic_partner"
        "spouse"
      when "court_appointed_guardian"
        "ward"
      else
        "child"
      end
    end

    def extract_rel_code(enrollee)
      sub_id = subscriber_id
      mem_id = extract_member_id(enrollee)
      prs = Maybe.new(enrollee).member.person_relationships.value
      return "child" if prs.blank?
      me_to_sub = prs.select do |pr|
        subj_ind = Maybe.new(pr).subject_individual.strip.split("#").last.value
        obj_ind = Maybe.new(pr).object_individual.strip.split("#").last.value
        (subj_ind == mem_id) && (obj_ind == sub_id)
      end
      sub_to_me = prs.select do |pr|
        subj_ind = Maybe.new(pr).subject_individual.strip.split("#").last.value
        obj_ind = Maybe.new(pr).object_individual.strip.split("#").last.value
        (subj_ind == sub_id) && (obj_ind == mem_id)
      end
      return "child" if (me_to_sub.empty? && sub_to_me.empty?)
      return extract_rel_from_me(me_to_sub.first) if me_to_sub.any?
      return extract_rel_from_sub(sub_to_me.first) if sub_to_me.any?
      "child"
    end

    def term_enrollee(policy, enrollee_node)
      member_id = extract_member_id(enrollee_node)
      enrollee = policy.enrollees.detect { |en| en.m_id == member_id }
      if enrollee 
        if @dropped_member_ids.include?(member_id)
          enrollee.coverage_end = extract_enrollee_end(enrollee_node)
          enrollee.coverage_status = "inactive"
          enrollee.employment_status_code = "terminated"
        end
        enrollee.pre_amt = extract_enrollee_premium(enrollee_node)
        enrollee.save!
        policy.save!
      end
    end

    def subscriber_id
      @subscriber_id ||= begin
                           sub_node = extract_subscriber(@policy_node)
                           extract_member_id(sub_node)
                         end
    end

    def populate_aptc_credit_changes(policy)
        new_aptc_date = policy.enrollees.map(&:coverage_end).uniq.compact.sort.last + 1.day
        tot_res_amt = extract_tot_res_amt
        pre_amt_tot = extract_pre_amt_tot
        aptc_amt = extract_aptc_amount
        policy.set_aptc_effective_on(new_aptc_date, aptc_amt, pre_amt_tot, tot_res_amt)
        policy.save!
    end

    def persist
      pol = policy_to_update
      existing_aptc = pol.applied_aptc
      pol.update_attributes!({
        :pre_amt_tot => extract_pre_amt_tot,
        :tot_res_amt => extract_tot_res_amt
      }.merge(extract_other_financials))
      policy_id = pol._id
      pol = Policy.find(policy_id)
      @policy_node.enrollees.each do |en|
        term_enrollee(pol, en)
      end
      unless all_terminations_exempt?(pol, @policy_node)
        Observers::PolicyUpdated.notify(pol)
      end
      populate_aptc_credit_changes(pol) if existing_aptc != extract_aptc_amount && !pol.is_shop?
      true
    end

    def all_terminations_exempt?(pol, policy_node)
      return false if pol.is_shop?
      enrollees_to_check = policy_node.enrollees.select do |en|
        member_id = extract_member_id(en)
        @dropped_member_ids.include?(member_id)
      end
      enrollees_to_check.all? do |en|
        member_exempt_from_termination_notification?(pol, en)
      end
    end

    def member_exempt_from_termination_notification?(pol, enrollee_node)
      end_date = extract_enrollee_end(enrollee_node)
      return false if end_date.blank?
      termination_event_exempt_from_notification?(pol, end_date, false)
    end
  end
end

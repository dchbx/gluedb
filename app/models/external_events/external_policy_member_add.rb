module ExternalEvents
  class ExternalPolicyMemberAdd
    attr_reader :policy_node
    attr_reader :added_member_ids
    attr_reader :policy_to_update

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    def initialize(pol_to_change, p_node, added_member_ids)
      @policy_node = p_node
      @added_member_ids = added_member_ids
      @policy_to_update = pol_to_change
    end

    def extract_pre_amt_tot
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).premium_total_amount.strip.value)
    end

    def extract_tot_res_amt
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return 0.00 if p_enrollment.blank?
      BigDecimal.new(Maybe.new(p_enrollment).total_responsible_amount.strip.value)
    end

    def extract_aptc_value
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return({}) if p_enrollment.blank?
      applied_aptc_val = Maybe.new(p_enrollment).individual_market.applied_aptc_amount.strip.value
      return nil if applied_aptc_val.blank?
      BigDecimal.new(applied_aptc_val)
    end

    def extract_enrollee_premium(enrollee)
      pre_string = Maybe.new(enrollee).benefit.premium_amount.value
      return 0.00 if pre_string.blank?
      BigDecimal.new(pre_string)
    end

    def extract_other_financials
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return({}) if p_enrollment.blank?
      if p_enrollment.shop_market
        tot_emp_res_amt = Maybe.new(p_enrollment).shop_market.total_employer_responsible_amount.strip.value
        employer = find_employer(@policy_node)
        return({ :employer => employer }) if tot_emp_res_amt.blank?
        {
          :employer => employer,
          :tot_emp_res_amt => BigDecimal.new(tot_emp_res_amt)
        }
      else
        applied_aptc_val = Maybe.new(p_enrollment).individual_market.applied_aptc_amount.strip.value
        return({}) if applied_aptc_val.blank?
        {
          :applied_aptc => BigDecimal.new(applied_aptc_val)
        }
      end
    end

    def extract_rel_from_me(rel)
      simple_relationship = Maybe.new(rel).relationship_uri.strip.split("#").last.downcase.value
      case simple_relationship
      when "life_partner", "domestic_partner"
        "life partner"
      when "spouse"
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
      when "life_partner", "domestic_partner"
        "life partner"
      when "spouse"
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

    def build_enrollee(policy, enrollee_node)
      member_id = extract_member_id(enrollee_node)
      if @added_member_ids.include?(member_id)
        policy.enrollees << Enrollee.new({
          :m_id => member_id,
          :rel_code => extract_rel_code(enrollee_node),
          :ben_stat => policy.is_cobra? ?  "cobra" : "active",
          :emp_stat => "active",
          :coverage_start => extract_enrollee_start(enrollee_node),
          :pre_amt => extract_enrollee_premium(enrollee_node)
        })
      else
        enrollee = policy.enrollees.detect { |en| en.m_id == member_id }
        if enrollee
          enrollee.pre_amt = extract_enrollee_premium(enrollee_node)
          enrollee.save!
        end
      end
      policy.save!
    end

    def subscriber_id
      @subscriber_id ||= begin
        sub_node = extract_subscriber(@policy_node)
        extract_member_id(sub_node)
      end
    end

    def populate_aptc_credit_changes(policy)
        new_aptc_date = policy.enrollees.map(&:coverage_start).uniq.sort.last
        tot_res_amt = extract_tot_res_amt
        pre_amt_tot = extract_pre_amt_tot
        aptc_amt = extract_aptc_value
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
      pol = Policy.find(pol._id)
      @policy_node.enrollees.each do |en|
        build_enrollee(pol, en)
      end
      Observers::PolicyUpdated.notify(pol)
      populate_aptc_credit_changes(pol) if existing_aptc != extract_aptc_value && !pol.is_shop?
      true
    end
  end
end

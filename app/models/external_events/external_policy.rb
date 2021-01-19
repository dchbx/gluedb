module ExternalEvents
  class ExternalPolicy
    attr_reader :policy_node
    attr_reader :plan
    attr_reader :kind

    attr_reader :created_policy

    include Handlers::EnrollmentEventXmlHelper

    # p_node : Openhbx::Cv2::Policy
    # p_record : Plan
    # optional parsing options to pass in additional parsed parameters to populate fields of policy
    # upon creation and persistance.
    def initialize(p_node, p_record, cobra_reinstate = false, **parsing_options)
      @policy_node = p_node
      @plan = p_record
      @cobra = cobra_reinstate
      @kind = parsing_options[:market_from_payload]
      @policy_reinstate = parsing_options[:policy_reinstate]
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

    def extract_cobra_eligibility_date
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      val = Maybe.new(p_enrollment).shop_market.cobra_eligibility_date.strip.value
      return nil if val.blank?
      Date.strptime(val, "%Y%m%d") rescue nil
    end

    def extract_enrollee_premium(enrollee)
      pre_string = Maybe.new(enrollee).benefit.premium_amount.value
      return 0.00 if pre_string.blank?
      BigDecimal.new(pre_string)
    end

    def extract_rating_details
      r_area = Maybe.new(@policy_node).policy_enrollment.rating_area.value
      c_plan_id = Maybe.new(@policy_node).policy_enrollment.plan.alias_ids.first.value
      potential_data = [
       [:rating_area, r_area],
       [:carrier_specific_plan_id, c_plan_id]
      ]
      potential_data.inject({}) do |acc, pair|
        unless pair.last.blank?
          acc[pair.first] = pair.last
        end
        acc
      end
    end

    def extract_other_financials
      p_enrollment = Maybe.new(@policy_node).policy_enrollment.value
      return({}) if p_enrollment.blank?
      if p_enrollment.shop_market
        tot_emp_res_amt = Maybe.new(p_enrollment).shop_market.total_employer_responsible_amount.strip.value
        composite_rating_tier_name = Maybe.new(p_enrollment).shop_market.composite_rating_tier_name.strip.value
        employer = find_employer(@policy_node)
        potential_data = [
          [:employer, employer],
          [:composite_rating_tier, composite_rating_tier_name],
          [:tot_emp_res_amt, tot_emp_res_amt]
        ]
        potential_data.inject({}) do |acc, pair|
          case pair.first
          when :employer
            acc[pair.first] = pair.last
          when :tot_emp_res_amt
            unless pair.last.blank?
              acc[pair.first] = BigDecimal.new(pair.last)
            end
          else
            unless pair.last.blank?
              acc[pair.first] = pair.last
            end
          end
          acc
        end
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
      policy.enrollees << Enrollee.new({
        :m_id => member_id,
        :rel_code => extract_rel_code(enrollee_node),
        :ben_stat => @cobra ? "cobra" : "active",
        :emp_stat => "active",
        :coverage_start => extract_enrollee_start(enrollee_node),
        :pre_amt => extract_enrollee_premium(enrollee_node)
      })
      policy.save!
    end

    def subscriber_id
      @subscriber_id ||= begin
        sub_node = extract_subscriber(@policy_node)
        extract_member_id(sub_node)
      end
    end

    def build_subscriber(policy)
      sub_node = extract_subscriber(@policy_node)
      policy.enrollees << Enrollee.new({
        :m_id => subscriber_id,
        :rel_code => "self",
        :ben_stat => @cobra ? "cobra" : "active",
        :emp_stat => "active",
        :coverage_start => extract_enrollee_start(sub_node),
        :pre_amt => extract_enrollee_premium(sub_node)
      })
      policy.save!
    end

    def build_responsible_party(responsible_person)
      if responsible_person_exists?
        responsible_person.responsible_parties << ResponsibleParty.new({:entity_identifier => "responsible party" })
        responsible_person.responsible_parties.first
      end
    end

    def policy_exists?
      eg_id = extract_enrollment_group_id(@policy_node)
      Policy.where(:hbx_enrollment_ids => eg_id).count > 0
    end

    def existing_policy
      eg_id = extract_enrollment_group_id(@policy_node)
      Policy.where(:hbx_enrollment_ids => eg_id).first if policy_exists?
    end

    def responsible_person_exists?
      authority_member_id = extract_responsible_party_id(@policy_node)
      Person.where('members.hbx_member_id' => authority_member_id).count > 0
    end

    def responsible_person
      authority_member_id = extract_responsible_party_id(@policy_node)
      return nil if authority_member_id.blank?
      Person.where("members.hbx_member_id" => authority_member_id).first if responsible_person_exists?
    end

    def responsible_party_exists?
      responsible_person_exists? && responsible_person.responsible_parties.any?
    end

    def existing_responsible_party
      responsible_person.responsible_parties.first if responsible_party_exists?
    end

    def persist
      return true if policy_exists?

      responsible_party_attributes = {}
      if !@policy_node.responsible_party.blank?
        responsible_party = responsible_party_exists? ? existing_responsible_party : build_responsible_party(responsible_person)
        responsible_party_attributes = { :responsible_party_id => responsible_party.id }
      end

      policy = Policy.create!({
        :plan => @plan,
        :carrier_id => @plan.carrier_id,
        :eg_id => extract_enrollment_group_id(@policy_node),
        :pre_amt_tot => extract_pre_amt_tot,
        :tot_res_amt => extract_tot_res_amt,
        :kind => @kind,
        :cobra_eligibility_date => @cobra ? extract_cobra_eligibility_date : nil
      }.merge(extract_other_financials).merge(extract_rating_details).merge(responsible_party_attributes))

      # reinstated policy aasm state need to be resubmitted
      if @policy_node.previous_policy_id.present? && @policy_reinstate
        policy.aasm_state = "resubmitted"
        #updating NPT flag on previous policy to false
        previous_policy = Policy.where(:hbx_enrollment_ids  => {"$in" => [@policy_node.previous_policy_id.to_s]}).first
        if previous_policy.present?
          previous_policy.update_attributes!(term_for_np: false)
          Observers::PolicyUpdated.notify(previous_policy)
        end
      end

      build_subscriber(policy)

      other_enrollees = @policy_node.enrollees.reject { |en| en.subscriber? }
      results = other_enrollees.each do |en|
        build_enrollee(policy, en)
      end
      Observers::PolicyUpdated.notify(policy)
      results
    end
  end
end

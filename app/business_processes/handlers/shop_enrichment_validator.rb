module Handlers
  class ShopEnrichmentValidator
    include EnrollmentEventXmlHelper

    attr_reader :errors, :enrollment_event_cv, :policy_cv, :last_event
    def initialize(errs, e_event_cv, p_cv, l_event)
      @errors = errs
      @enrollment_event_cv = e_event_cv
      @policy_cv = p_cv
      @last_event = l_event
    end

    def valid?
      shop_enrollment = extract_shop_enrollment(policy_cv)
      if shop_enrollment.nil?
        errors.add(:employer, "Could not locate shop elements")
        errors.add(:employer, l_event)
        return false
      end
      employer_link = extract_employer_link(policy_cv)
      if shop_enrollment.nil?
        errors.add(:employer, "Could not locate employer_link element")
        errors.add(:employer, l_event)
        return false
      end
      employer = find_employer(policy_cv)
      if employer.nil?
        errors.add(:employer, "Could not locate employer \"#{employer_link.id}\"")
        errors.add(:employer, l_event)
        return false
      end
      plan_year = find_employer_plan_year(policy_cv)
      if plan_year.nil?
        errors.add(:employer, "Could employer has no plan year for this period")
        errors.add(:employer, l_event)
        return false
      end
      if competing_coverage(enrollment_event_cv, policy_cv).any?
        errors.add(:process, "We found competing coverage for this enrollment.  We don't currently process that.")
        errors.add(:process, last_event)
        return false
      end
      true
    end

    def should_be_shop_plan_change?
    end

    def competing_coverage(enrollment_event_cv, policy_cv, plan_year, employer)
      subscriber_enrollee = extract_subscriber(policy_cv)
      subscriber_start = extract_enrollee_start(subscriber_enrollee)
      subscriber_person = Person.find_by_member_id(subscriber_id)
      return [] if subscriber_person.nil?
      subscriber_end = extract_enrollee_end(subscriber_enrollee)
      if subscriber_end.blank?
        subscriber_end = plan_year.end_date
      end
      plan = extract_plan(policy_cv)
      subscriber_person.policies.select do |pol|
        overlapping_policy?(pol, plan, employer, subscriber_id, subscriber_start, subscriber_end)
      end
    end

    def extract_enrollment_action(enrollment_event_cv)
      Maybe.new(enrollment_event_cv).event.body.enrollment.enrollment_type.strip.value
    end

    def is_ivl_active_renewal?(enrollment_event_cv)
      return false if (determine_market(enrollment_event_cv) == "shop")
      [
        "urn:openhbx:terms:v1:enrollment#active_renew"
      ].include?(extract_enrollment_action(enrollment_event_cv))
    end

    def overlapping_policy?(pol, plan, employer, subscriber_id, subscriber_start, subscriber_end)
      return false if pol.canceled?
      return false if pol.subscriber.blank?
      return false if (pol.subscriber.m_id != subscriber_id)
      return false unless (plan.coverage_type == pol.plan.coverage_type)
      return false if pol.employer_id.blank?
      return false unless (pol.employer_id == employer.id)
      pol.coverage_period.overlaps?(subscriber_start..subscriber_end)
    end
  end
end

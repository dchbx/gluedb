module Observers
  class PolicyUpdated

    def self.notify(policy, time = Time.now)
      notify_of_federal_reporting_changes(policy, time)
    end

    def self.check_for_npt_flag_end_date(policy, before_updated_policy)
      policy.term_for_np == before_updated_policy.term_for_np && before_updated_policy.policy_end.nil?
    end

    def self.check_for_termination_date(policy)
      if policy.policy_end.present? && policy.policy_end == policy.policy_end.try(:end_of_year)
        if policy.versions.present?
          before_updated_policy = policy.versions.order_by(updated_at: :desc).first
          check_for_npt_flag_end_date(policy, before_updated_policy) && check_dependent_end_date(policy, before_updated_policy)
        end
      end
    end

    def self.check_dependent_end_date(policy, before_updated_policy)
      policy.enrollees.each do |enrollee|
        unless enrollee.rel_code == "self"
          before_updated_policy.enrollees.each do |previous_enrollee|
            unless previous_enrollee.rel_code == "self"
              if enrollee.id == previous_enrollee.id
                # it return false only when
                # previous enrollee coverage_end date is not an end of that year
                # current version enrollee coverage_end is equal to end of that year
                return false if previous_enrollee.coverage_end != previous_enrollee.coverage_end.try(:end_of_year) && enrollee.coverage_end == enrollee.coverage_end.try(:end_of_year)
              end
            end
          end
        end
      end
      true
    end

    def self.notify_of_federal_reporting_changes(policy, time)
      # Coverall policies are are not considered part of IVL marketplace
      return if policy.kind == 'coverall'
      return if policy.is_shop?
      return if policy.coverage_type.to_s.downcase != "health"
      return if policy.coverage_year.first.year == time.year
      return if policy.coverage_year.first.year < 2018
      return if check_for_termination_date(policy)
      ::Amqp::EventBroadcaster.with_broadcaster do |b|
        b.broadcast(
          {
            :headers => {
              :policy_id => policy.id,
              :eg_id => policy.eg_id
            },
            :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
          },
          ""
        )
      end
    end
  end
end
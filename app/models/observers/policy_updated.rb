module Observers
  class PolicyUpdated

    def self.notify(policy, time = Time.now)
      notify_of_federal_reporting_changes(policy, time)
    end

    def self.notify_of_federal_reporting_changes(policy, time)
      # Coverall policies are are not considered part of IVL marketplace
      return if policy.kind == 'coverall'
      return if policy.is_shop?
      return if policy.plan.metal_level == "catastrophic"
      return if policy.coverage_type.to_s.downcase != "health"
      return if policy.coverage_year.first.year == time.year
      return if policy.coverage_year.first.year < 2018
      ::Amqp::EventBroadcaster.with_broadcaster do |b|
        b.broadcast(
          {
            :headers => {
              :policy_id => policy.id,
              :eg_id => policy.eg_id,
              :submitted_timestamp => Time.now.to_s
            },
            :routing_key => "info.events.policy.federal_reporting_eligibility_updated"
          },
          ""
        )
      end
    end
  end
end
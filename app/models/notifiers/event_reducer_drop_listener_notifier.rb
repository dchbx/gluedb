module Notifiers
  class EventReducerDropListener

    def self.notify( time = Time.now)
      notify_reducer_digest_drop_listener(time)
    end

    def self.notify_reducer_digest_drop_listener(time)
      ::Amqp::EventBroadcaster.with_broadcaster do |b|
        b.broadcast(
          {
            :headers => {
            },
            :routing_key => "info.events.policy.report_eligibility_updated.requested"
          },
          ""
        )
      end
    end
  end
end
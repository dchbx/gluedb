module PolicyEvents
  class ReportingEligibilityUpdated
    include Mongoid::Document
    include Mongoid::Timestamps

    field :event_time, type: Time
    field :processed_at, type: Time
    field :policy_id, type: String
    field :eg_id, type: String
    field :worker_id, type: String
    field :retry_count, type: Integer, default: 0
    field :status, type: String, default: "queued"

    index({event_time: 1, worker_id: 1, status: 1})
    index({policy_id: 1, status: 1})

    def self.store_new_event(policy_id, eg_id, event_time = Time.now)
      old_record = self.where({
        :status => "queued",
        :policy_id => policy_id
      }).first
      if old_record
        old_record.update_attributes!({event_time: event_time})
        old_record
      else
        self.create!({
          policy_id: policy_id,
          eg_id: eg_id,
          event_time: event_time
        })
      end
    end

    def self.events_for_processing(time = Time.now)
      # Use the current OS PID to take ownership of our batch
      worker_pid = Process.pid.to_s
      self.where({
        :status => "queued",
        :event_time => {"$lte" => time}
      }).update_all(
        {"$set" => {:status => "processing", :worker_id => worker_pid}}
      )
      self.where({
        :status => "processing",
        :worker_id => worker_pid
      }).each do |record|
        we_did_it_right, the_error = yield record
        if we_did_it_right
          record.update_attributes!({
            :status => "processed",
            :processed_at => Time.now
          })
        else
          record.attempt_retry(the_error, Time.now)
        end
      end
    end

    def attempt_retry(the_error, at_time)
      if self.retry_count < 5
        self.update_attributes!(
          :status => "queued",
          :retry_count => self.retry_count + 1
        )
      else
        self.update_attributes!(
          :status => "error"
        )
        Amqp::EventBroadcaster.with_broadcaster do |eb|
          error_message = {
            :message => the_error.message,
            :inspected => the_error.inspect,
            :backtrace => the_error.backtrace.join("\n")
          }
          err_json = error_message.to_json.encode('UTF-8', undef: :replace, replace: '')
          eb.broadcast(
            {
              :routing_key => "critical.application.gluedb.report_eligibility_updated_event.processing_failure",
              :headers => {
                :return_status => "500",
                :eg_id => self.eg_id.to_s,
                :policy_id => self.policy_id.to_s,
                :event_id => self.id.to_s
              }
            },
            err_json
          )
        end
      end
    end
  end
end

module Listeners
  class PaymentProcessorTransactionListener < Amqp::RetryClient
    XML_NS = {
      proc: 'http://dchealthlink.com/vocabularies/1/process',
      ins: "http://dchealthlink.com/vocabularies/1/insured"
    }

     def self.queue_name
      ec = ExchangeInformation
      "#{ec.hbx_id}.#{ec.environment}.q.glue.payment_processor_transaction_listener"
    end

     def self.create_bindings(chan, q)
      ec = ExchangeInformation
      event_topic_exchange_name = "#{ec.hbx_id}.#{ec.environment}.e.topic.events"
      event_topic_exchange = chan.topic(event_topic_exchange_name, {:durable => true})
      q.bind(event_topic_exchange, {:routing_key => "info.events.payment_processor_transaction.transmitted"})
    end

     def self.create_queues(chan)
      q = chan.queue(
        self.queue_name,
        {
          :durable => true,
          :arguments => {
            "x-dead-letter-exchange" => (self.queue_name + "-retry")
          }
        }
      )
      retry_q = chan.queue(
        (self.queue_name + "-retry"),
        {
          :durable => true,
          :arguments => {
            "x-dead-letter-exchange" => (self.queue_name + "-requeue"),
            "x-message-ttl" => 1000
          }
        }
      )
      retry_exchange = chan.fanout(
        (self.queue_name + "-retry")
      )
      requeue_exchange = chan.fanout(
        (self.queue_name + "-requeue")
      )
      retry_q.bind(retry_exchange, {:routing_key => ""})
      q.bind(requeue_exchange, {:routing_key => ""})
      q
    end

    def self.run
      Process.setproctitle("%s - %s" % [self.name , $$])
      conn = AmqpConnectionProvider.start_connection
      chan = conn.create_channel
      q = create_queues(chan)
      create_bindings(chan, q)
      chan.prefetch(1)
      self.new(chan, q).subscribe(:block => true, :manual_ack => true, :ack => true)
      conn.close
    end

     def on_message(delivery_info, properties, body)
      m_headers = (properties.headers || {}).to_hash.stringify_keys

       submitted_at = properties.timestamp
      location = m_headers['upload_location'].to_s
      unless create_record(submitted_at, location, body) 
        broadcast_error(location, submitted_at, body)
      end
      channel.ack(delivery_info.delivery_tag, false)
    end

     private

     def create_record(submitted_at, location, body)
      return nil if location.blank?
      enrollment_group_id = extract_enrollment_group_id(body)
      return nil if enrollment_group_id.blank?
      policy = Policy.where({eg_id: enrollment_group_id}).first
      return nil unless policy
      storage_prefix = "/payment_processor_uploads/"
      storage_location = File.join(storage_prefix, location)
      payload_as_a_file = FileString.new(storage_location, body)
      reason = extract_reason(body)
      action = extract_action(body)

       Protocols::LegacyCv::LegacyCvTransaction.create!({
        body: payload_as_a_file,
        eg_id: enrollment_group_id,
        reason: reason,
        action: action,
        location: location,
        submitted_at: submitted_at,
        policy_id: policy.id
      })
    end

     def broadcast_error(location, submitted_at, body)
      eb = Amqp::EventBroadcaster.new(channel.connection)
      eb.broadcast(
        {"routing_key"=>
          "error.application.gluedb.payment_processor_transaction_listener.invalid_message",
          "headers"=> {
            "return_status"=>"422",
            "submitted_at"=> submitted_at,
            "location"=> location
          }
        },
        body
      )
    end

     def extract_action(xml_payload)
      doc = Nokogiri::XML(xml_payload)
      return nil if doc.blank?
      Maybe.new(doc).at_xpath("//proc:type", XML_NS).content.strip.value
    end

     def extract_reason(xml_payload)
      doc = Nokogiri::XML(xml_payload)
      return nil if doc.blank?
      Maybe.new(doc).at_xpath("//proc:reason", XML_NS).content.strip.value
    end

     def extract_enrollment_group_id(xml_payload)
      doc = Nokogiri::XML(xml_payload)
      return nil if doc.blank?
      Maybe.new(doc).at_xpath("//ins:exchange_policy_id", XML_NS).content.strip.value
    end
  end
end

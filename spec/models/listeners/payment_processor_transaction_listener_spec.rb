require 'rails_helper'

 describe Listeners::PaymentProcessorTransactionListener do
  let(:connection) { double }
  let(:queue) { double }
  let(:channel) { double(:connection => connection) }

   subject { Listeners::PaymentProcessorTransactionListener.new(channel, queue) }

   context "given a message with the required data" do
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag) }
    let(:body) do
      File.read("./spec/data/legacy_cvs/409190.xml")
    end
    let(:enrollment_group_id) { "409190" }
    let(:headers) do
      {
        "upload_location" => location
      }
    end
    let(:properties) do
      double(
        headers: headers,
        timestamp: submitted_at
      )
    end
    let(:submitted_at) { DateTime.now }
    let(:location) { '/fake_folder/folder/fake_transaction_file.text' }
    let(:storage_location) { '/payment_processor_uploads/fake_folder/folder/fake_transaction_file.text' }
    let(:payload_as_a_file) { double }
    let(:record_properties) do
      {
        submitted_at: submitted_at,
        eg_id: enrollment_group_id,
        location: location,
        action: 'add',
        reason: 'initial_enrollment',
        body: payload_as_a_file,
        policy_id: policy_id
      }
    end

     let(:policy)  { instance_double(Policy, :id => policy_id) }

     let(:policy_id) { double }

     let(:new_record) { double }

     before do
      allow(Policy).to receive(:where).with({:eg_id => enrollment_group_id}).and_return([policy])
      allow(FileString).to receive(:new).with(storage_location, body).and_return(payload_as_a_file)
      allow(Protocols::LegacyCv::LegacyCvTransaction).to receive(:create!).with(record_properties).and_return(new_record)
      allow(channel).to receive(:ack).with(delivery_tag, false)
    end

     it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end

     it "creates the transaction record" do
      expect(Protocols::LegacyCv::LegacyCvTransaction).to receive(:create!).with(record_properties)
      subject.on_message(delivery_info, properties, body)
    end
  end

   context "given a message with an xml that has no enrollment group id" do
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag) }
    let(:body) do
      "<ksdjfklejfsdf"
    end
    let(:headers) do
      {
        "upload_location" => location
      }
    end
    let(:properties) do
      double(
        headers: headers,
        timestamp: submitted_at
      )
    end
    let(:submitted_at) { DateTime.now }
    let(:location) { '/fake_folder/folder/fake_transaction_file.text' }

     let(:event_broadcaster) do
      instance_double(Amqp::EventBroadcaster)
    end

     let(:error_message_properties) do
      {
        "routing_key"  => "error.application.gluedb.payment_processor_transaction_listener.invalid_message",
        "headers" => {
          "return_status" => "422",
          "submitted_at" => submitted_at,
          "location" => location
        }
      }
    end

     before(:each) do
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      allow(channel).to receive(:ack).with(delivery_tag, false)
    end

     it "broadcasts an error event" do
      expect(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      subject.on_message(delivery_info, properties, body)
    end

     it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end
  end

   context "given a message with an invalid enrollment group id" do
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag) }
    let(:body) do
      File.read("./spec/data/legacy_cvs/409190.xml")
    end
    let(:enrollment_group_id) { "409190" }
    let(:headers) do
      {
        "upload_location" => location
      }
    end
    let(:properties) do
      double(
        headers: headers,
        timestamp: submitted_at
      )
    end
    let(:submitted_at) { DateTime.now }
    let(:location) { '/fake_folder/folder/fake_transaction_file.text' }

     let(:event_broadcaster) do
      instance_double(Amqp::EventBroadcaster)
    end

     let(:error_message_properties) do
      {
        "routing_key"  => "error.application.gluedb.payment_processor_transaction_listener.invalid_message",
        "headers" => {
          "return_status" => "422",
          "submitted_at" => submitted_at,
          "location" => location
        }
      }
    end

     before(:each) do
      allow(Policy).to receive(:where).with({:eg_id => enrollment_group_id}).and_return([])
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      allow(channel).to receive(:ack).with(delivery_tag, false)
    end

     it "broadcasts an error event" do
      expect(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      subject.on_message(delivery_info, properties, body)
    end

     it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end
  end

   context "given a message with no location" do
    let(:delivery_tag) { double }
    let(:delivery_info) { double(delivery_tag: delivery_tag) }
    let(:body) do
      File.read("./spec/data/legacy_cvs/409190.xml")
    end
    let(:enrollment_group_id) { "409190" }
    let(:headers) do
      {
        "upload_location" => location
      }
    end
    let(:properties) do
      double(
        headers: headers,
        timestamp: submitted_at
      )
    end
    let(:submitted_at) { DateTime.now }
    let(:location) { nil }

     let(:event_broadcaster) do
      instance_double(Amqp::EventBroadcaster)
    end

     let(:error_message_properties) do
      {
        "routing_key"  => "error.application.gluedb.payment_processor_transaction_listener.invalid_message",
        "headers" => {
          "return_status" => "422",
          "submitted_at" => submitted_at,
          "location" => ""
        }
      }
    end

     before(:each) do
      allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
      allow(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      allow(channel).to receive(:ack).with(delivery_tag, false)
    end

     it "broadcasts an error event" do
      expect(event_broadcaster).to receive(:broadcast).with(error_message_properties, body)
      subject.on_message(delivery_info, properties, body)
    end

     it "acknowledges the message" do
      expect(channel).to receive(:ack).with(delivery_tag, false)
      subject.on_message(delivery_info, properties, body)
    end
  end
end

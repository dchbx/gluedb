require "rails_helper"

describe Listeners::ReportEligibilityUpdatedReducerListener do
  let(:mock_connection) { double }
  let(:mock_channel) { double(queue: mock_queue, connection: mock_connection) }
  let(:mock_queue) { double }
  let(:mock_p_headers) { {} }
  let(:mock_delivery_info) { double(delivery_tag: "FakeDeliveryTag") }
  let(:mock_properties) { double(headers: mock_properties_headers, timestamp: Time.now) }
  let(:mock_properties_headers) do
    {
      policy_id: policy_id,
      eg_id: eg_id
    }
  end
  let(:policy_id) { "A POLICY ID" }
  let(:eg_id) { "AN EG ID" }
  let(:event_time) { Time.now }

  subject do
    Listeners::ReportEligibilityUpdatedReducerListener.new(mock_channel, mock_queue)
  end

  before :each do
    allow(mock_connection).to receive(:create_channel).and_return(mock_channel)
    allow(mock_channel).to receive(:ack).with("FakeDeliveryTag", false)
    allow(Time).to receive(:now).and_return(event_time)
  end

  it "acks the message" do
    subject.on_message(mock_delivery_info, mock_properties, "")
  end

  it "updates the reporting eligiblity model" do
    expect(PolicyEvents::ReportingEligibilityUpdated).to receive(
      :store_new_event
    ).with(policy_id, eg_id, event_time)
    subject.on_message(mock_delivery_info, mock_properties, "")
  end
end

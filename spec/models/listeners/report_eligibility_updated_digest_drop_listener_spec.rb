require "rails_helper"

describe Listeners::ReportEligibilityUpdatedDigestDropListener do
  let(:mock_connection) { double }
  let(:mock_channel) { double(queue: mock_queue, fanout: mock_fanout, connection: mock_connection) }
  let(:mock_queue) { double }
  let(:mock_fanout) { double }
  let(:mock_retry_queue_bind) { double }
  let(:retry_queue_bind){ double }
  let(:mock_queue_bind) { double }
  let(:mock_create_queues) { double }
  let(:mock_create_bindings) { double }
  let(:mock_prefetch) { double }
  let(:mock_new_report_eligibility_digest_drop_reducer_listener) do
    Listeners::ReportEligibilityUpdatedDigestDropListener.new(mock_channel, mock_create_queues)
  end
  let(:mock_subscribe) { double }
  let(:mock_close) { double }
  let(:mock_p_headers) { {} }
  let(:mock_delivery_info) { double(delivery_tag: "FakeDeliveryTag") }
  let(:mock_policy) { instance_double('Policy', id: 1, eg_id: 2) }
  let(:mock_properties) { double(headers: mock_properties_headers, timestamp: Time.now) }
  let(:mock_properties_headers) do
    {
      policy_id: mock_policy.id,
      eg_id: mock_policy.eg_id
    }
  end
  let(:mock_body) { double }
  let(:mock_ack) { double }

  let(:old_record) do
    PolicyEvents::ReportingEligibilityUpdated.create!(
      policy_id: mock_policy.id,
      status: 'queued',
      event_time: Time.now - 1.week,
    )
  end

  subject { Listeners::ReportEligibilityUpdatedDigestDropListener }

  before :each do
    allow(AmqpConnectionProvider).to receive(:start_connection).and_return(mock_connection)
    allow(mock_connection).to receive(:create_channel).and_return(mock_channel)
    allow(subject).to receive(:create_queues).with(mock_channel).and_return(mock_create_queues)
    allow(subject).to receive(:create_bindings).with(mock_channel, mock_create_queues).and_return(mock_create_bindings)
    allow(mock_channel).to receive(:prefetch).with(1).and_return(mock_prefetch)
    allow(subject).to receive(:new).with(mock_channel, mock_create_queues).and_return(mock_new_report_eligibility_digest_drop_reducer_listener)
    allow(mock_new_report_eligibility_digest_drop_reducer_listener).to receive(:subscribe).with(:block => true, :manual_ack => true, :ack => true)
    allow(mock_connection).to receive(:close).and_return(mock_close)
    allow(mock_new_report_eligibility_digest_drop_reducer_listener).to receive(:passes_validation?).with(
      true, true, true
    ).and_return(true)
    allow(mock_channel).to receive(:ack).with(mock_delivery_info.delivery_tag, false).and_return(true)
    allow(::FederalReports::ReportEligiblityDetermination).to receive(:determine_report_transmission_type).and_return(true)

    PolicyEvents::ReportingEligibilityUpdated.delete_all
  end

  it "should run successfully" do
    old_record
    subject.run
  end

  it "should trigger the policy events report eligibility updated on message" do
    old_record_original_event_time = old_record.event_time
    expect(PolicyEvents::ReportingEligibilityUpdated.all.count).to eq(1)
    mock_new_report_eligibility_digest_drop_reducer_listener.on_message(mock_delivery_info, mock_properties, mock_body){} 
    expect(::FederalReports::ReportEligiblityDetermination).to have_received(:determine_report_transmission_type)
  end
end
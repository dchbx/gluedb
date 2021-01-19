require "rails_helper"

describe EmployerEvents::EmployerEdiContactInfoNotificationSet, "given an AMQP connection" do

  let(:connection) { double }

  subject { EmployerEvents::EmployerEdiContactInfoNotificationSet.new(connection) }

  let(:employer_list) { [1,2] }

  let(:event_broadcaster) { instance_double(Amqp::EventBroadcaster) }

  before :each do
    allow(Amqp::EventBroadcaster).to receive(:new).with(connection).and_return(event_broadcaster)
  end

  describe "told to send notifications for a list of employers, when no events have been broadcast" do

    it "sends notifications for those employers" do
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.events.employer_edi.contact_information_updates_requested",
        :headers => {
          :employer_id => "1"
        }
      }, "")
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.events.employer_edi.contact_information_updates_requested",
        :headers => {
          :employer_id => "2"
        }
      }, "")
      subject.notify_for_outstanding_employers_from_list(employer_list)
    end
  end

  describe "told to send notifications for a list of employers, when some of those employers have already been broadcast" do
    it "only sends one notification per employer" do
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.events.employer_edi.contact_information_updates_requested",
        :headers => {
          :employer_id => "1"
        }
      }, "").exactly(:once)
      expect(event_broadcaster).to receive(:broadcast).with({
        :routing_key => "info.events.employer_edi.contact_information_updates_requested",
        :headers => {
          :employer_id => "2"
        }
      }, "").exactly(:once)
      subject.notify_for_outstanding_employers_from_list([1])
      subject.notify_for_outstanding_employers_from_list(employer_list)
    end
  end
end
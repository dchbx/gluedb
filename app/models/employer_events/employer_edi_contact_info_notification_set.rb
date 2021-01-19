require "set"

module EmployerEvents
  class EmployerEdiContactInfoNotificationSet

    def initialize(connection)
      @connection = connection
      @already_sent_employers = Set.new
    end

    def notify_for_outstanding_employers_from_list(employer_id_list)
      broadcaster = Amqp::EventBroadcaster.new(@connection)
      sendable_employers = employer_id_list - @already_sent_employers.to_a
      sendable_employers.each do |e_id|
        broadcaster.broadcast({
          :routing_key => "info.events.employer_edi.contact_information_updates_requested",
          :headers => {
            :employer_id => e_id.to_s
          }
        }, "")
      end
      @already_sent_employers.merge(employer_id_list)
    end
  end
end
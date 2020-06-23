module ChangeSets
  class IdentityChangeTransmitter
    attr_reader :affected_member, :policy, :event_kind, :enrollees

    # affected_member :: BusinessProcesses::AffectedMember
    # pol :: Policy
    # event_kind :: String (uri)
    def initialize(affected_member, pol, event_kind)
      @affected_member = affected_member
      @policy = pol
      @event_kind = event_kind
      active_member_ids = policy.active_member_ids
      @enrollees = policy.enrollees.select do |en|
         active_member_ids.include?(en.m_id)
      end
    end

    def publish
       return true unless @policy.active_member_ids.include?(@affected_member.member_id)
       render_result = ApplicationController.new.render_to_string(
         :layout => "enrollment_event",
         :partial => "enrollment_events/enrollment_event",
         :format => :xml,
         :locals => {
           :affected_members => [affected_member],
           :policy => policy,
           :enrollees => enrollees,
           :event_type => event_kind,
           :transaction_id => transaction_id
         })
#       Rails.logger.error { "RENDERED RESULT: #{render_result}" }
       conn = AmqpConnectionProvider.start_connection
       transmitter = ::Services::EnrollmentEventTransmitter.new
       transmitter.call(conn, render_result)
       conn.close
    end

    def transaction_id
      @transcation_id ||= TransactionIdGenerator.generate_bgn02_compatible_transaction_id
    end
  end
end

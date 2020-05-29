# Put an Enrollment Event CV onto the bus after transforming
module Publishers
  class TradingPartnerEdi
    include Handlers::EnrollmentEventXmlHelper

    X12_NS = { :etf => "urn:x12:schemas:005:010:834A1A1:BenefitEnrollmentAndMaintenance" }

    attr_reader :event_xml
    attr_reader :error_message
    attr_reader :amqp_connection
    attr_reader :errors

    def initialize(amqp_c, e_xml)
      @amqp_connection = amqp_c
      @event_xml = e_xml
      @errors = ActiveModel::Errors.new(self)
    end

    def publish
      action_xml = event_xml
      enrollment_event_cv = enrollment_event_cv_for(action_xml)
      if is_publishable?(enrollment_event_cv)
        begin
          publish_transaction_id = new_transaction_id
          enrollment_with_transaction_id = update_transaction_id(action_xml, publish_transaction_id)
          edi_builder = EdiCodec::X12::BenefitEnrollment.new(enrollment_with_transaction_id)
          x12_xml = edi_builder.call.to_xml
          publish_to_bus(amqp_connection, enrollment_event_cv, x12_xml, publish_transaction_id)
        rescue Exception => e
          errors.add(:error_message, e.message)
          errors.add(:event_xml, event_xml)
          return false
        end
      end
      true
    end

    def publish_to_bus(amqp_connection, enrollment_event_cv, x12_payload, transaction_id)
      ::Amqp::ConfirmedPublisher.with_confirmed_channel(amqp_connection) do |chan|
        ex = chan.default_exchange
        ex.publish(x12_payload, :routing_key => routing_key(x12_payload), :headers => {
          "market" => determine_market(enrollment_event_cv),
          "file_name" => determine_file_name(enrollment_event_cv, x12_payload, transaction_id)
        })
      end
    end

    def find_carrier_abbreviation(enrollment_event_cv)
      policy_cv = extract_policy(enrollment_event_cv)
      hios_id = extract_hios_id(policy_cv)
      active_year = extract_active_year(policy_cv)
      found_plan = Plan.where(:hios_plan_id => hios_id, :year => active_year.to_i).first
      found_plan.carrier.abbrev.upcase
    end

    def determine_file_name(enrollment_event_cv, x12_xml, transaction_id)
      market_identifier = shop_market?(enrollment_event_cv) ? "S" : "I"
      carrier_identifier = find_carrier_abbreviation(enrollment_event_cv)
      category_identifier = is_initial?(x12_xml) ? "_C_E_" : "_C_M_"
      "834_" + transaction_id + "_" + carrier_identifier + category_identifier + market_identifier + "_1.xml"
    end

    protected

    def new_transaction_id
      TransactionIdGenerator.generate_bgn02_compatible_transaction_id
    end

    def update_transaction_id(action_xml, change_bgn = false)
      return action_xml unless change_bgn
      new_id_for_bgn = new_transaction_id
      the_xml = Nokogiri::XML(action_xml)
      the_xml.xpath("//cv:enrollment/cv:transaction_id/cv:id", {:cv => "http://openhbx.org/api/terms/1.0"}).each do |node|
        node.content = new_id_for_bgn
      end
      the_xml.xpath("//cv:enrollment_event_body/cv:transaction_id", {:cv => "http://openhbx.org/api/terms/1.0"}).each do |node|
        node.content = new_id_for_bgn
      end
      the_xml.to_xml(:indent => 2)
    end

    def is_publishable?(enrollment_event_cv)
      Maybe.new(enrollment_event_cv).event.body.publishable?.value
    end

    def is_initial?(x12_xml)
      x12_doc = Nokogiri::XML(x12_xml)
      "021" == x12_doc.at_xpath("//etf:INS_MemberLevelDetail_2000[contains(etf:INS01__MemberIndicator,'Y')]/etf:INS03__MaintenanceTypeCode", X12_NS).content.strip
    end

    def routing_key(x12_xml)
      is_initial?(x12_xml) ? "hbx.enrollment_messages" : "hbx.maintenance_messages"
    end

    def transaction_id(enrollment_event_cv)
      Maybe.new(enrollment_event_cv).event.body.transaction_id.strip.value
    end

    def shop_market?(enrollment_event_cv)
      determine_market(enrollment_event_cv) == "shop"
    end

    # Errors stuff for ActiveModel::Errors
    def read_attribute_for_validation(attr)
      send(attr)
    end

    def self.human_attribute_name(attr, options = {})
      attr
    end

    def self.lookup_ancestors
      [self]
    end
  end
end

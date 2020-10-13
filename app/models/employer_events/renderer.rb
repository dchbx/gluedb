module EmployerEvents
  class Renderer
    XML_NS = "http://openhbx.org/api/terms/1.0"

    attr_reader :employer_event
    attr_reader :timestamp

    def initialize(e_event)
      @employer_event = e_event
      @timestamp = e_event.event_time
    end

    def carrier_plan_years(carrier)
      doc = Nokogiri::XML(employer_event.resource_body)
      doc.xpath("//cv:elected_plans/cv:elected_plan/cv:carrier/cv:id/cv:id[text() = '#{carrier.hbx_carrier_id}']/../../../../../../..", {:cv => XML_NS})
    end

    def has_current_or_future_plan_year?(carrier)
      found_plan_year = false
      found_start_date = nil
      found_end_date = nil
      carrier_plan_years(carrier).each do |node|
        node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
          date_value = Date.strptime(date_node.content, "%Y%m%d") rescue nil
          if date_value
            found_start_date = date_value
            if date_value >= Date.today
              found_plan_year = true
            end
          end
        end
        node.xpath("cv:plan_year_end", {:cv => XML_NS}).each do |date_node|
          date_value = Date.strptime(date_node.content, "%Y%m%d") rescue nil
          if date_value
            found_end_date = date_value
            if date_value >= Date.today
              found_plan_year = true
            end
          end
        end
      end
      return false if found_start_date && found_end_date && (found_start_date == found_end_date)
      found_plan_year
    end

    def should_send_retroactive_term_or_cancel?(carrier)
      events = EmployerEvents::EventNames::TERMINATION_EVENT + [EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT]
      return false unless events.include?(employer_event.event_name)
      doc = Nokogiri::XML(employer_event.resource_body)
      all_plan_years = doc.xpath("//cv:plan_year", {:cv => XML_NS})
      return false if all_plan_years.empty?
      sorted_plan_years = all_plan_years.sort_by do |node|
        Date.strptime(node.xpath("cv:plan_year_start", {:cv => XML_NS}).first.content,"%Y%m%d") rescue nil
      end
      last_plan_year = sorted_plan_years.last
      if last_plan_year.present? && last_plan_year.xpath(".//cv:elected_plans/cv:elected_plan/cv:carrier/cv:id/cv:id[text() = '#{carrier.hbx_carrier_id}']", {:cv => XML_NS}).any?
        start_date = Date.strptime(last_plan_year.xpath("cv:plan_year_start", {:cv => XML_NS}).first.content,"%Y%m%d") rescue nil
        end_date = Date.strptime(last_plan_year.xpath("cv:plan_year_end", {:cv => XML_NS}).first.content,"%Y%m%d") rescue nil
        return false if start_date.blank? || end_date.blank?
        if employer_event.event_name == EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT
          start_date == end_date
        else
          start_date != end_date && end_date > Date.today - 1.year
        end
      else
        false
      end
    end

    def renewal_and_no_future_plan_year?(carrier)
      return false if employer_event.event_name != EmployerEvents::EventNames::RENEWAL_SUCCESSFUL_EVENT
      found_future_plan_year = false
      carrier_plan_years(carrier).each do |node|
        node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
          date_value = Date.strptime(date_node.content, "%Y%m%d") rescue nil
          if date_value
            if date_value > Date.today
              found_future_plan_year = true
            end
          end
        end
      end
      !found_future_plan_year
    end

    def drop_and_has_future_plan_year?(carrier)
      return false if employer_event.event_name != EmployerEvents::EventNames::RENEWAL_CARRIER_CHANGE_EVENT
      found_future_plan_year = false
      carrier_plan_years(carrier).each do |node|
        end_date = Date.strptime(node.xpath("cv:plan_year_end", {:cv => XML_NS}).first.content,"%Y%m%d") rescue nil
        node.xpath("cv:plan_year_start", {:cv => XML_NS}).each do |date_node|
          date_value = Date.strptime(date_node.content, "%Y%m%d") rescue nil
          if date_value
            if date_value > Date.today && date_value != end_date
              found_future_plan_year = true
            end
          end
        end
      end
      found_future_plan_year
    end

    # Return true if we rendered anything
    def render_for(carrier, out)
      unless ::EmployerEvents::EventNames::EVENT_WHITELIST.include?(@employer_event.event_name)
        return false
      end

      doc = Nokogiri::XML(employer_event.resource_body)

      unless carrier_plan_years(carrier).any?
        return false
      end

      return false unless has_current_or_future_plan_year?(carrier) || should_send_retroactive_term_or_cancel?(carrier)
      return false if drop_and_has_future_plan_year?(carrier)
      return false if renewal_and_no_future_plan_year?(carrier)

      doc.xpath("//cv:elected_plans/cv:elected_plan", {:cv => XML_NS}).each do |node|
        carrier_id = node.at_xpath("cv:carrier/cv:id/cv:id", {:cv => XML_NS}).content
        if carrier_id != carrier.hbx_carrier_id 
          node.remove
        end
      end
      doc.xpath("//cv:employer_census_families", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:benefit_group/cv:reference_plan", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:benefit_group/cv:elected_plans[not(cv:elected_plan)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:broker_agency_profile[not(cv:brokers)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:employer_profile/cv:brokers[not(cv:broker_account)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:benefit_group[not(cv:elected_plans)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:plan_year/cv:benefit_groups[not(cv:benefit_group)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      doc.xpath("//cv:plan_year[not(cv:benefit_groups)]", {:cv => XML_NS}).each do |node|
        node.remove
      end
      event_header = <<-XMLHEADER
                        <employer_event>
                                <event_name>urn:openhbx:events:v1:employer##{employer_event.event_name}</event_name>
                                <resource_instance_uri>
                                        <id>urn:openhbx:resource:organization:id##{employer_event.employer_id}</id>
                                </resource_instance_uri>
                                <body>
      XMLHEADER
      event_trailer = <<-XMLTRAILER
                                </body>
                        </employer_event>
      XMLTRAILER
      out << event_header
      out << doc.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION, :indent => 2)
      out << event_trailer
      true
    end
  end
end

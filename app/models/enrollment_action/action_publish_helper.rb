module EnrollmentAction
  class ActionPublishHelper
    XML_NS = { :cv => "http://openhbx.org/api/terms/1.0" }
    attr_reader :event_xml_doc

    include MoneyMath

    def initialize(xml_string)
      @event_xml_doc = Nokogiri::XML(xml_string)
    end

    def to_xml
      if is_shop?
        add_employer_contacts_and_office_locations
      end
      @event_xml_doc.to_xml
    end

    def is_shop?
      event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:shop_market", XML_NS).any?
    end

    def filter_affected_members(affected_member_ids)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if affected_member_ids.include?(member_id)
            found_matching_id = true
          end
        end
        unless found_matching_id
          node.remove
        end
      end
      event_xml_doc
    end

    def filter_enrollee_members(affected_member_ids)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if affected_member_ids.include?(member_id)
            found_matching_id = true
          end
        end
        unless found_matching_id
          node.remove
        end
      end
      event_xml_doc
    end

    def set_member_ends(member_end_date)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", XML_NS).each do |node|
        node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
          d_node.content = member_end_date.strftime("%Y%m%d")
        end
      end
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
          d_node.content = member_end_date.strftime("%Y%m%d")
        end
      end
      event_xml_doc
    end

    def keep_member_ends(member_ids)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if !member_ids.include?(member_id)
            node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
              d_node.remove
            end
          end
        end
      end
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if !member_ids.include?(member_id)
            node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
              d_node.remove
            end
          end
        end
      end
      event_xml_doc
    end

    def recalculate_premium_totals_excluding_dropped_dependents(remaining_enrollees)
      ## loop through existing enrollees
      premium_total = 0
      event_xml_doc.xpath("//cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          node_member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if remaining_enrollees.include? node_member_id
            enrollee_premium = node.xpath("cv:benefit/cv:premium_amount", XML_NS).first.content.to_f
            premium_total = premium_total + enrollee_premium
          end
        end
      end

      ## copy new total into totals value
      event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:premium_total_amount", XML_NS).each do |node|
        node.content = as_dollars(premium_total)
      end

      ## SHOP: check if there is an employer contribution... do nothing if not SHOP
      employer_contribution = 0
      event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:shop_market", XML_NS).each do |node|
        employer_contribution_path = node.xpath("cv:total_employer_responsible_amount", XML_NS).first
        employer_contribution = employer_contribution_path.content.to_f
        if (employer_contribution > premium_total)
          employer_contribution = premium_total
          employer_contribution_path.content = as_dollars(employer_contribution)
        end
      end

      ## IVL: check if there is an applied_aptc_amount... do nothing if not IVL
      assistance_contribution = 0
      event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:individual_market", XML_NS).each do |node|
        assistance_contribution_path = node.xpath("cv:applied_aptc_amount", XML_NS).first
        assistance_contribution = assistance_contribution_path.content.to_f
        if (assistance_contribution > premium_total)
          assistance_contribution = premium_total
          assistance_contribution_path.content = as_dollars(assistance_contribution)
        end
      end

      ## adjust the individual responsible total accordingly
      event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:total_responsible_amount", XML_NS).each do |node|
        node.content = as_dollars(premium_total - employer_contribution - assistance_contribution)
      end
      event_xml_doc
    end

    def set_member_starts(member_start_hash)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if member_start_hash.keys.include?(member_id)
            new_date = member_start_hash[member_id]
            node.xpath("cv:benefit/cv:begin_date", XML_NS).each do |d_node|
              unless new_date.blank?
                d_node.content = new_date.strftime("%Y%m%d")
              end
            end
          end
        end
      end
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        found_matching_id = false
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if member_start_hash.keys.include?(member_id)
            new_date = member_start_hash[member_id]
            node.xpath("cv:benefit/cv:begin_date", XML_NS).each do |d_node|
              unless new_date.blank?
                d_node.content = new_date.strftime("%Y%m%d")
              end
            end
          end
        end
      end
      event_xml_doc
    end

    def set_member_end_date(member_end_hash)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:affected_members/cv:affected_member", XML_NS).each do |node|
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if member_end_hash.keys.include?(member_id)
            new_date = member_end_hash[member_id]
            node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
              unless new_date.blank?
                d_node.content = new_date.strftime("%Y%m%d")
              end
            end
          end
        end
      end

      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |node|
        node.xpath("cv:member/cv:id/cv:id", XML_NS).each do |c_node|
          member_id = Maybe.new(c_node).content.strip.split("#").last.value
          if member_end_hash.keys.include?(member_id)
            new_date = member_end_hash[member_id]
            node.xpath("cv:benefit/cv:end_date", XML_NS).each do |d_node|
              unless new_date.blank?
                d_node.content = new_date.strftime("%Y%m%d")
              end
            end
          end
        end
      end
      event_xml_doc
    end

    def set_event_action(event_action_value)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:type", XML_NS).each do |node|
        node.content = event_action_value
      end
      event_xml_doc
    end

    def set_market_type(event_action_value)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:market", XML_NS).each do |node|
        node.content = event_action_value
      end
      event_xml_doc
    end

    def set_policy_id(policy_id_value)
      event_xml_doc.xpath("//cv:enrollment_event_body/cv:enrollment/cv:policy/cv:id/cv:id", XML_NS).each do |node|
        node.content = policy_id_value
      end
      event_xml_doc
    end

    def replace_premium_totals(other_event_xml)
      other_event_doc = Nokogiri::XML(other_event_xml)
      other_event_doc.xpath("//cv:policy/cv:enrollment/cv:premium_total_amount", XML_NS).each do |other_node|
        event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:premium_total_amount", XML_NS).each do |node|
          node.content = other_node.content
        end
      end

      other_event_doc.xpath("//cv:policy/cv:enrollment/cv:total_responsible_amount", XML_NS).each do |other_node|
        event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:total_responsible_amount", XML_NS).each do |node|
          node.content = other_node.content
        end
      end
      other_event_doc.xpath("//cv:policy/cv:enrollment/cv:shop_market/cv:total_employer_responsible_amount", XML_NS).each do |other_node|
        event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:shop_market/cv:total_employer_responsible_amount", XML_NS).each do |node|
          node.content = other_node.content
        end
      end
      other_event_doc.xpath("//cv:policy/cv:enrollment/cv:individual_market/cv:applied_aptc_amount", XML_NS).each do |other_node|
        event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:individual_market/cv:applied_aptc_amount", XML_NS).each do |node|
          node.content = other_node.content
        end
      end
      event_xml_doc.xpath("//cv:policy/cv:enrollees/cv:enrollee", XML_NS).each do |event_enrollee|
        member_id_node = event_enrollee.xpath("cv:member/cv:id/cv:id", XML_NS).first 
        if member_id_node
          member_id_value = member_id_node.content
          premium_node = event_enrollee.xpath("cv:benefit/cv:premium_amount", XML_NS).first
          if premium_node
            matching_enrollee_node = other_event_doc.xpath("//cv:policy/cv:enrollees/cv:enrollee", XML_NS).detect do |other_event_enrollee|
                other_member_id_node = other_event_enrollee.xpath("cv:member/cv:id/cv:id", XML_NS).first
                if other_member_id_node
                  (other_member_id_node.content == member_id_value)
                else
                  false
                end
            end
            if matching_enrollee_node
              matching_premium_node = matching_enrollee_node.xpath("cv:benefit/cv:premium_amount", XML_NS).first
              if matching_premium_node
                premium_node.content = matching_premium_node.content
              end
            end
          end
        end
      end
      event_xml_doc
    end

    def swap_qualifying_event(source_event_xml)
      source_event_doc = Nokogiri::XML(source_event_xml)
      source_event_doc.xpath("//cv:enrollment/cv:policy/cv:eligibility_event", XML_NS).each do |source_node|
        event_xml_doc.xpath("//cv:enrollment/cv:policy/cv:eligibility_event", XML_NS).each do |target_node|
          target_node.replace(source_node.dup)
        end
      end
    end

    def assign_assistance_date(assistance_date)
        assistance_effective_node = event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:individual_market/cv:assistance_effective_date", XML_NS).first
        if assistance_effective_node
          assistance_effective_node.content = assistance_date.strftime("%Y%m%d")
        else
          event_xml_doc.xpath("//cv:policy/cv:enrollment/cv:individual_market", XML_NS).each do |node|
            new_node = Nokogiri::XML::Node.new("assistance_effective_date", event_xml_doc)
#            new_node.namespace = XML_NS[:cv]
            new_node.content = assistance_date.strftime("%Y%m%d")
            node << new_node
          end
        end
        event_xml_doc
    end

    def take_rating_tier_from(other_xml)
      @other_xml_doc = Nokogiri::XML(other_xml)
      other_rating_node = @other_xml_doc.xpath("//cv:shop_market/cv:composite_rating_tier_name", XML_NS).first
      if other_rating_node
        @event_xml_doc.xpath("//cv:shop_market/cv:composite_rating_tier_name", XML_NS).each do |node|
          node.content = other_rating_node.content
        end
      end
    end

    private

    def add_employer_contacts_and_office_locations
      employer_id_node = event_xml_doc.at_xpath("//cv:enrollment/cv:shop_market/cv:employer_link/cv:id/cv:id", XML_NS)
      employer_id = Maybe.new(employer_id_node).content.strip.split("#").last.value
      if employer_id
        employer = Employer.where(:hbx_id => employer_id).first
        if employer
          cont = ApplicationController.new
          unless event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link/cv:contacts", XML_NS).any?
            add_contact_xml_for(cont, employer)
          end
          unless event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link/cv:office_locations", XML_NS).any?
            add_office_location_xml_for(cont, employer)
          end
        end
      end
    end

    def add_contact_xml_for(controller, employer)
      contact_xml = controller.render_to_string(
        :layout => nil,
        :partial => "enrollment_events/employer_with_contacts",
        :object => employer,
        :format => :xml
      )
      contact_xml_doc = Nokogiri::XML(contact_xml)
      contact_xml_node = contact_xml_doc.root
      if contact_xml_node
        ol_node = event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link/cv:office_locations", XML_NS).first
        if ol_node
          ol_node.add_previous_sibling(contact_xml_node)
        else
          el_node = event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link", XML_NS).first
          el_node.add_child(contact_xml_node)
        end
      end
    end

    def add_office_location_xml_for(controller, employer)
      ol_xml = controller.render_to_string(
        :layout => nil,
        :partial => "enrollment_events/employer_with_office_locations",
        :object => employer,
        :format => :xml
      )
      ol_xml_doc = Nokogiri::XML(ol_xml)
      ol_xml_node = ol_xml_doc.root
      if ol_xml_node
        contact_xml_node = event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link/cv:contacts", XML_NS).first
        if contact_xml_node
          contact_xml_node.add_next_sibling(ol_xml_node)
        else
          el_node = event_xml_doc.xpath("//cv:enrollment/cv:shop_market/cv:employer_link", XML_NS).first
          el_node.add_child(ol_xml_node)
        end
      end
    end
  end
end

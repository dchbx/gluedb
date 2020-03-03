require "securerandom"

module ExternalEvents
  class EnrollmentEventNotification
    attr_reader :timestamp
    attr_reader :event_xml
    attr_reader :message_tag
    attr_reader :errors
    attr_reader :event_responder
    attr_reader :headers
    attr_reader :business_process_history

    include Handlers::EnrollmentEventXmlHelper

    def initialize(e_responder, m_tag, t_stamp, e_xml, headers)
      @business_process_history = Array.new
      @errors = ActiveModel::Errors.new(self)
      @headers = headers
      @errors = []
      @timestamp = t_stamp
      @droppable = false
      @bogus_termination = false
      @bogus_renewal_termination = false
      @event_responder = e_responder
      @message_tag = m_tag
      @event_xml = e_xml
    end

    def hash
      bucket_id.hash
    end

    def bucket_id
      [subscriber_id, coverage_type, employer_hbx_id]
    end

    def mark_for_drop!
      @droppable = true
    end

    def drop_payload_duplicate!
      response_with_publisher do |result_publisher|
        result_publisher.drop_payload_duplicate!(self)
      end
    end

    def drop_if_already_processed_termination!
      return false unless already_processed_termination?
      response_with_publisher do |result_publisher|
        result_publisher.drop_already_processed!(self)
      end
    end

    def drop_if_term_with_no_end!
      return false unless is_termination?
      return false unless subscriber_end.blank?
      response_with_publisher do |result_publisher|
        result_publisher.drop_no_end_date_termination!(self)
      end
    end

    def drop_if_already_processed!
      found_event = ::EnrollmentAction::EnrollmentActionIssue.where(
        :hbx_enrollment_id => hbx_enrollment_id,
        :enrollment_action_uri => enrollment_action
      )
      if found_event.any?
        response_with_publisher do |result_publisher|
          result_publisher.drop_already_processed!(self)
        end
      else
        false
      end
    end

    def drop_if_bogus_term!
      return false unless @bogus_termination
      response_with_publisher do |result_publisher|
        result_publisher.drop_bogus_term!(self)
      end
    end

    def drop_if_bogus_plan_year!
      return false unless has_bogus_plan_year?
      response_with_publisher do |result_publisher|
        result_publisher.drop_bogus_plan_year!(self)
      end
    end

    def has_bogus_plan_year?
      return false unless is_shop?
      plan_year = find_employer_plan_year(policy_cv)
      return false if plan_year.present?

      if plan_year.nil? && is_termination?
        employer = find_employer(policy_cv)
        plan_year = employer.plan_years.to_a.detect do |py|
          (py.start_date <= subscriber_start) && ((py.start_date + 1.year - 1.day) >= subscriber_start)
        end
        plan_year.nil?
      else
        true
      end
    end

    def clean_ivars
      # GC hint
      instance_variables.each do |iv|
        unless iv.to_s == "@business_process_history"
          instance_variable_set(iv, nil)
        end
      end
    end

    def drop_if_marked!
      return false unless @droppable
      response_with_publisher do |result_publisher|
        result_publisher.drop_reduced_event!(self)
      end
    end

    def check_for_bogus_renewal_term_against(other)
      return nil if other.is_termination?
      return nil unless is_termination?
      return nil unless (subscriber_end == (other.subscriber_start - 1.day))
      return nil unless (other.active_year.to_i == active_year.to_i - 1)
      @bogus_renewal_termination = true
    end

    def drop_if_bogus_renewal_term!
      return false unless @bogus_renewal_termination
      response_with_publisher do |result_publisher|
        result_publisher.drop_bogus_renewal_term!(self)
      end
    end

    def flow_successful!(action_name, batch_id, batch_index)
      response_with_publisher do |result_publisher|
        result_publisher.flow_successful!(self, action_name, batch_id, batch_index)
      end
    end


    def drop_not_yet_implemented!(action_name, batch_id, batch_index)
      response_with_publisher do |result_publisher|
        result_publisher.drop_not_yet_implemented!(self, action_name, batch_id, batch_index)
      end
    end

    def no_event_found!(batch_id, index)
      response_with_publisher do |result_publisher|
        result_publisher.no_event_found!(self, batch_id, index)
      end
    end

    def persist_failed!(action_name, publish_errors, batch_id, batch_index)
      response_with_publisher do |result_publisher|
        result_publisher.persist_failed!(self, action_name, publish_errors, batch_id, batch_index)
      end
    end

    def publish_failed!(action_name, publish_errors, batch_id, batch_index)
      response_with_publisher do |result_publisher|
        result_publisher.publish_failed!(self, action_name, publish_errors, batch_id, batch_index)
      end
    end

    def response_with_publisher
      result_publisher = Publishers::EnrollmentEventNotificationResult.new(event_responder, event_xml, headers, message_tag)

      yield result_publisher
      # gc hint by nilling out references
      clean_ivars
      true
    end

    def check_for_bogus_term_against(others)
      return unless is_termination?
      others.each do |other|
        if (other.hbx_enrollment_id == hbx_enrollment_id) && other.is_coverage_starter?
          @bogus_termination = false
          return
        end
      end
      @bogus_termination = (is_reterm_with_earlier_date? || existing_policy.nil?)
    end

    def check_and_mark_duplication_against(other)
      if duplicates?(other)
        self.mark_for_drop!
        other.mark_for_drop!
      end
    end

    def duplicates?(other)
      return false unless other.hbx_enrollment_id == hbx_enrollment_id
      ((!other.is_termination?) && self.is_cancel?) ||
        (other.is_cancel? && (!self.is_termination?))
    end

    def is_coverage_starter?
      [
        "urn:openhbx:terms:v1:enrollment#initial",
        "urn:openhbx:terms:v1:enrollment#auto_renew",
        "urn:openhbx:terms:v1:enrollment#active_renew"
      ].include?(enrollment_action)
    end

    def edge_for(graph, other)
      if other.hbx_enrollment_id == hbx_enrollment_id
        case [other.is_termination?, is_termination?]
        when [true, false]
          graph.add_edge(self, other)
        when [false, true]
          graph.add_edge(other, self)
        else
          :ok
        end
      elsif other.active_year != active_year
        comp = active_year.to_i <=> other.active_year.to_i
        if comp == -1
          graph.add_edge(self, other)
        elsif comp == 1
          graph.add_edge(other, self)
        end
      elsif submitted_at_time != other.submitted_at_time
        comp = submitted_at_time <=> other.submitted_at_time
        if comp == -1
          graph.add_edge(self, other)
        elsif comp == 1
          graph.add_edge(other, self)
        end
      elsif subscriber_start != other.subscriber_start
        comp = subscriber_start <=> other.subscriber_start
        if comp == -1
          graph.add_edge(self, other)
        elsif comp == 1
          graph.add_edge(other, self)
        end
      else
        case [subscriber_end.nil?, other.subscriber_end.nil?]
        when [true, true]
          :ok
        when [false, true]
          graph.add_edge(self, other)
        when [true, false]
          graph.add_edge(other, self)
        else
          comp = subscriber_end <=> other.subscriber_end
          if comp == -1
            graph.add_edge(self, other)
          elsif comp == 1
            graph.add_edge(other, self)
          end
        end
      end
    end

    def subscriber_start
      @subscriber_start ||= extract_enrollee_start(subscriber)
    end

    def subscriber_end
      @subscriber_end ||= extract_enrollee_end(subscriber)
    end

    def is_passive_renewal?
      (enrollment_action == "urn:openhbx:terms:v1:enrollment#auto_renew")
    end

    def is_termination?
      (enrollment_action == "urn:openhbx:terms:v1:enrollment#terminate_enrollment")
    end

    def is_cobra?
      extract_market_kind(enrollment_event_xml) == "cobra"
    end

    def is_cancel?
      return false unless (enrollment_action == "urn:openhbx:terms:v1:enrollment#terminate_enrollment")
      extract_enrollee_start(subscriber) >= extract_enrollee_end(subscriber)
    end

    def is_reterm_with_earlier_date? # terminating policy again with earlier or later date, but not with future date.
      return false unless is_termination?
      return false unless subscriber_end.present?
      return false if subscriber_end > Date.today
      return false unless policy_cv.previous_policy_id.present?

      existing_policy = Policy.where(hbx_enrollment_ids: policy_cv.previous_policy_id).first
      return false unless (existing_policy.present? && existing_policy.terminated?)
      return false unless ((existing_policy.subscriber.m_id == subscriber_id) && (subscriber_start >= existing_policy.policy_start))

      member_date_map = {}
      policy_cv.enrollees.map { |en| member_date_map[extract_member_id(en)] = extract_enrollee_start(en)}

      if all_member_ids.all? { |m_id| existing_policy.enrollees.map(&:m_id).include?(m_id) }
        all_member_ids.all? do |mem_id|
          en = existing_policy.enrollees.select{|en| en.m_id == mem_id}.first
          member_date_map[mem_id] >= en.coverage_start
        end
      else
        false
      end
    end

    def enrollment_action
      @enrollment_action ||= extract_enrollment_action(enrollment_event_xml)
    end

    def enrollment_event_xml
      @enrollment_event_xml ||= enrollment_event_cv_for(event_xml)
    end

    def policy_cv
      @policy_cv ||= extract_policy(enrollment_event_xml)
    end

    def hbx_enrollment_id
      @hbx_enrollment_id ||= Maybe.new(policy_cv).id.value
    end

    def subscriber
      @subscriber ||= extract_subscriber(policy_cv)
    end

    def subscriber_id
      @subscriber_id ||= extract_member_id(subscriber)
    end

    def active_year
      @active_year ||= extract_active_year(policy_cv)
    end

    def kind
      @kind ||= extract_market_kind(enrollment_event_xml)
    end

    def is_adjacent_to?(other)
      return false unless active_year == other.active_year
      case [is_termination?, other.is_termination?]
      when [true, true]
        false
      when [false, false]
        false
      when [false, true]
        false
      else
        (self.subscriber_end == other.subscriber_start - 1.day) || (self.is_cancel? && (subscriber_start == other.subscriber_start))
      end
    end

    def employer_hbx_id
      @employer_hbx_id ||= begin
                             if determine_market(enrollment_event_xml) == "individual"
                               nil
                             else
                               Maybe.new(policy_cv).policy_enrollment.shop_market.employer_link.id.strip.split("#").last.value
                             end
                           end
    end

    def is_shop?
      !employer_hbx_id.blank?
    end
    
    def submitted_at_time
      timestamp_value = Maybe.new(enrollment_event_xml).header.submitted_timestamp.value
      Time.strptime(timestamp_value, "%Y-%m-%dT%H:%M:%S") rescue nil
    end

    def submitted_at_time
      timestamp_value = Maybe.new(enrollment_event_xml).header.submitted_timestamp.value
      Time.strptime(timestamp_value, "%Y-%m-%dT%H:%M:%S") rescue nil
    end

    def coverage_type
      @coverage_type ||= Maybe.new(policy_cv).policy_enrollment.plan.is_dental_only.value
    end

    def update_business_process_history(entry)
      @business_process_history = @business_process_history + [entry]
    end

    def all_member_ids
      @all_member_ids ||= policy_cv.enrollees.map do |en|
        Maybe.new(en.member.id).strip.split("#").last.value
      end
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

    def existing_policy
      @existing_policy ||= Policy.where(hbx_enrollment_ids: hbx_enrollment_id).first
    end

    def existing_plan
      @existing_plan ||= extract_plan(policy_cv)
    end

    def is_publishable?
      Maybe.new(enrollment_event_xml).event.body.publishable?.value
    end

    def already_processed_termination?
      return false unless is_termination?
      return false if existing_policy.blank?
      return true if existing_policy.canceled?
      if existing_policy.terminated?
        !is_cancel?
      else
        false
      end
    end

    private

    def initialize_clone(other)
      @business_process_history = other.business_process_history.clone
      @headers = other.headers.clone
      @timestamp = other.timestamp.clone
      @event_xml = other.event_xml.clone
      @message_tag = other.message_tag.clone
      @event_responder = other.event_responder
      @errors = other.errors.clone
    end
  end
end

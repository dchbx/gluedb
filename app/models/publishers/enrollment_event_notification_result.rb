module Publishers
  class EnrollmentEventNotificationResult
    attr_reader :event_responder
    attr_reader :event_xml
    attr_reader :headers
    attr_reader :message_tag

    def initialize(e_responder, event_xml, headers, message_tag)
      @event_responder = e_responder
      @event_xml = event_xml
      @headers = headers
      @message_tag = message_tag
    end

    def drop_bogus_plan_year!(event_notification)
      event_responder.broadcast_response(
        "error",
        "invalid_plan_year",
        "422",
        event_xml,
        headers
      )
      store_error_model(
        event_notification,
        "invalid_plan_year",
        headers.merge({
          "return_status" => "422"
        })
      )
      event_responder.ack_message(message_tag)
    end

    def drop_bogus_term!(event_notification)
      event_responder.broadcast_response(
        "error",
        "unmatched_termination",
        "422",
        event_xml,
        headers
      )
      store_error_model(
        event_notification,
        "unmatched_termination",
        headers.merge({
          "return_status" => "422"
        })
      )
      event_responder.ack_message(message_tag)
    end

    def drop_no_end_date_termination!(event_notification)
      event_responder.broadcast_response(
        "error",
        "termination_without_end_date",
        "422",
        event_xml,
        headers
      )
      store_error_model(
        event_notification,
        "termination_without_end_date",
        headers.merge({
          "return_status" => "422"
        })
      )
      event_responder.ack_message(message_tag)
    end

    def drop_payload_duplicate!(event_notification)
      event_responder.broadcast_ok_response(
        "duplicate_event_payload",
        event_xml,
        headers.merge({
          hbx_enrollment_id: event_notification.hbx_enrollment_id,
          enrollment_action_uri: event_notification.enrollment_action
        })
      )
      event_responder.ack_message(message_tag)
    end

    def drop_reduced_event!(event_notification)
      event_responder.broadcast_ok_response(
        "enrollment_reduced",
        event_xml,
        headers.merge({
          hbx_enrollment_id: event_notification.hbx_enrollment_id,
          enrollment_action_uri: event_notification.enrollment_action
        })
      )
      event_responder.ack_message(message_tag)
    end

    def drop_already_processed!(event_notification)
      event_responder.broadcast_ok_response(
        "event_already_processed",
        event_xml,
        headers
      )
      event_responder.ack_message(message_tag)
    end

    def drop_bogus_renewal_term!(event_notification)
      event_responder.broadcast_ok_response(
        "renewal_termination_reduced",
        event_xml,
        headers
      )
      event_responder.ack_message(message_tag)
    end

    def drop_not_yet_implemented!(event_notification, action_name, batch_id, batch_index)
      event_responder.broadcast_response(
        "error",
        "not_yet_implemented",
        "422",
        event_xml,
        headers.merge({
          :not_implented_action => action_name
        })
      )
      store_error_model(
        event_notification,
        "not_yet_implemented",
        headers.merge({
          "return_status" => "422",
          "not_implemented_action" => action_name
        }),
        {
          :batch_id => batch_id,
          :batch_index => batch_index
        }
      )
      event_responder.ack_message(message_tag)
    end

    def persist_failed!(event_notification, action_name, publish_errors, batch_id, batch_index)
      event_responder.broadcast_response(
        "error",
        "persist_failed",
        "500",
        publish_errors.merge({
          :original_xml => event_xml
        }).to_json,
        headers.merge({
          :batch_id => batch_id,
          :batch_index => batch_index,
          :action_name => action_name
        })
      )
      store_error_model(
        event_notification,
        "persist_failed",
        headers.merge({
          "return_status" => "500",
          "action_name" => action_name
        }).merge(publish_errors),
        {
          :batch_id => batch_id,
          :batch_index => batch_index
        }
      )
      event_responder.ack_message(message_tag)
    end

    def publish_failed!(event_notification, action_name, publish_errors, batch_id, batch_index)
      event_responder.broadcast_response(
        "error",
        "publish_failed",
        "500",
        publish_errors.merge({
          :original_xml => event_xml
        }).to_json,
        headers.merge({
          :batch_id => batch_id,
          :batch_index => batch_index,
          :action_name => action_name
        })
      )
      store_error_model(
        event_notification,
        "publish_failed",
        headers.merge({
          "return_status" => "500",
          "action_name" => action_name
        }).merge(publish_errors),
        {
          :batch_id => batch_id,
          :batch_index => batch_index
        }
      )
      event_responder.ack_message(message_tag)
    end

    def no_event_found!(event_notification, batch_id, index)
      event_responder.broadcast_response(
        "error",
        "unknown_enrollment_action",
        "422",
        event_xml,
        headers.merge({
          :batch_id => batch_id,
          :batch_index => index
        })
      )
      store_error_model(
        event_notification,
        "unknown_enrollment_action",
        headers.merge({
          "return_status" => "422"
        }),
        {
          :batch_id => batch_id,
          :batch_index => index
        }
      )
      event_responder.ack_message(message_tag)
    end

    def flow_successful!(event_notification, action_name, batch_id, batch_index)
      event_responder.broadcast_response(
        "info",
        "event_processed",
        "200",
        event_xml,
        headers.merge({
          :enrollment_action => action_name
        })
      )
      store_error_model(
        event_notification,
        "processed_successfully",
        headers.merge({
          "return_status" => "200",
          "action_name" => action_name
        }),
        {
          :batch_id => batch_id,
          :batch_index => batch_index
        }
      )
      event_responder.ack_message(message_tag)
    end

    def store_error_model(event_notification, err_msg, err_headers, other_props = {})
      EnrollmentAction::EnrollmentActionIssue.create!({
        :hbx_enrollment_id => event_notification.hbx_enrollment_id,
        :hbx_enrollment_vocabulary => event_xml,
        :enrollment_action_uri => event_notification.enrollment_action,
        :error_message => err_msg,
        :headers => err_headers,
        :received_at => event_notification.timestamp
      }.merge(other_props))
    end
  end
end

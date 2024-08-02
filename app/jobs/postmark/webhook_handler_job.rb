# frozen_string_literal: true

module Postmark
  class WebhookHandlerJob < ::ApplicationJob
    queue_as :low

    def perform(payload)
      email = payload[:recipient] || payload[:email]
      delivery = Newsletter::Delivery.find_by_email_and_tag(email, payload[:tag])

      if delivery
        if delivery.processing?
          event = payload[:record_type].downcase
          send("handle_#{event}", delivery, payload)
        else
          SLog.log(:irrelevant_postmark_webhook, **payload)
        end
      else
        SLog.log(:unmatched_postmark_webhook, **payload)
      end
    end

    private

    def handle_delivery(delivery, payload)
      delivery.delivered!(
        at: payload[:delivered_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details])
    end

    def handle_bounce(delivery, payload)
      delivery.bounced!(
        at: payload[:bounced_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details],
        bounce_type: payload[:type],
        bounce_type_code: payload[:type_code],
        bounce_description: payload[:description])
    end
  end
end

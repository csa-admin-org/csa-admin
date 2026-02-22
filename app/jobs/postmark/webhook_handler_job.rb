# frozen_string_literal: true

module Postmark
  class WebhookHandlerJob < ApplicationJob
    queue_as :low

    def perform(payload)
      email = MailDelivery::Email.find_by(postmark_message_id: payload[:message_id])

      if email.nil?
        Rails.event.notify(:unmatched_postmark_webhook, **payload)
      elsif email.processing?
        event = payload[:record_type].downcase
        send("handle_#{event}", email, payload)
      else
        Rails.event.notify(:irrelevant_postmark_webhook, **payload)
      end
    end

    private

    def handle_delivery(email, payload)
      email.delivered!(
        at: payload[:delivered_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details])
    end

    def handle_bounce(email, payload)
      email.bounced!(
        at: payload[:bounced_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details],
        bounce_type: payload[:type],
        bounce_type_code: payload[:type_code],
        bounce_description: payload[:description])
    end
  end
end

# frozen_string_literal: true

# Handles Postmark webhook payloads for both broadcast (newsletter) and
# outbound (transactional) message streams.
#
# Lookup strategy:
# 1. Primary: find MailDelivery::Email by postmark_message_id (set via
#    after_deliver callback). This matches template emails and newsletter
#    emails where the postmark_message_id was captured at send time.
# 2. Fallback: find MailDelivery::Email by tag + email. This matches
#    backfilled newsletter records that may not have a postmark_message_id
#    (e.g., records migrated from the legacy newsletter_deliveries table).
#
# Idempotency: webhooks are no-ops when the record is already in a
# terminal state (delivered/bounced). Postmark may retry webhooks, so
# duplicate payloads must not cause errors.
module Postmark
  class WebhookHandlerJob < ApplicationJob
    queue_as :low

    def perform(payload)
      message_id = payload[:message_id]
      email_address = payload[:recipient] || payload[:email]

      # Primary lookup: MailDelivery::Email by unique postmark_message_id
      record = MailDelivery::Email.find_by(postmark_message_id: message_id)

      # Fallback: MailDelivery::Email by tag + email (for backfilled records
      # without postmark_message_id, where tag encodes the newsletter_id)
      unless record
        newsletter_id = extract_newsletter_id(payload[:tag])
        if newsletter_id && email_address
          record = MailDelivery::Email
            .joins(:mail_delivery)
            .merge(MailDelivery.newsletter_id_eq(newsletter_id))
            .find_by(email: email_address)
        end
      end

      if record.nil?
        Rails.event.notify(:unmatched_postmark_webhook, **payload)
      elsif record.processing?
        event = payload[:record_type].downcase
        send("handle_#{event}", record, payload)
      else
        Rails.event.notify(:irrelevant_postmark_webhook, **payload)
      end
    end

    private

    def handle_delivery(record, payload)
      record.delivered!(
        at: payload[:delivered_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details])
    end

    def handle_bounce(record, payload)
      record.bounced!(
        at: payload[:bounced_at],
        postmark_message_id: payload[:message_id],
        postmark_details: payload[:details],
        bounce_type: payload[:type],
        bounce_type_code: payload[:type_code],
        bounce_description: payload[:description])
    end

    # Extracts newsletter_id from a Postmark tag like "newsletter-42".
    # Returns nil if the tag doesn't match the newsletter pattern.
    def extract_newsletter_id(tag)
      return unless tag.to_s.start_with?("newsletter-")

      tag.split("-").last.to_i
    end
  end
end

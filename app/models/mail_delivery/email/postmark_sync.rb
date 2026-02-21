# frozen_string_literal: true

# Syncs delivery status from Postmark API for emails stuck in processing.
# Used as a safety net when webhooks are missed or fail to be processed.
#
# Called hourly by Scheduled::PostmarkSyncDeliveriesJob via the
# class method sync_stale_from_postmark!, which finds emails still
# in processing state after CONSIDER_STALE_AFTER and checks their
# actual status via the Postmark API.
module MailDelivery::Email::PostmarkSync
  extend ActiveSupport::Concern

  CONSIDER_STALE_AFTER = 12.hours

  included do
    scope :stale, -> { processing.where(created_at: ...CONSIDER_STALE_AFTER.ago) }
  end

  class_methods do
    # Syncs stale processing emails from Postmark API.
    # Safety net for missed or failed webhooks.
    def sync_stale_from_postmark!
      stale.where.not(postmark_message_id: nil).find_each do |email|
        email.sync_from_postmark!
      rescue => e
        Rails.event.notify(:postmark_sync_error, email_id: email.id, error: e.message)
      end
    end
  end

  # Fetches message details from Postmark API and transitions to
  # delivered or bounced based on the message events.
  def sync_from_postmark!
    return unless processing?

    details = PostmarkWrapper.get_message(postmark_message_id)
    return unless details[:status].in?(%w[Sent Processed])

    events = details[:message_events]

    if (event = events.find { |e| e["Type"] == "Delivered" && e["Recipient"] == self.email })
      delivered!(
        at: event["ReceivedAt"],
        postmark_message_id: postmark_message_id,
        postmark_details: event.dig("Details", "DeliveryMessage"))
    elsif (event = events.find { |e| e["Type"] == "Bounced" && e["Recipient"] == self.email })
      bounce = PostmarkWrapper.get_bounce(event.dig("Details", "BounceID"))
      bounced!(
        at: bounce[:bounced_at],
        postmark_message_id: bounce[:message_id],
        postmark_details: bounce[:details],
        bounce_type: bounce[:type],
        bounce_type_code: bounce[:type_code],
        bounce_description: bounce[:description])
    end
  end
end

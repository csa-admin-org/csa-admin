# frozen_string_literal: true

# Per-email-address delivery tracking for a MailDelivery.
#
# Each record represents one actual email sent to one address.
# A single MailDelivery (per member) may have multiple Email children
# when the member has several email addresses.
#
# Tracks delivery state via Postmark webhooks using `postmark_message_id`
# as the primary lookup key. Suppressed emails are detected at creation
# time via `check_email_suppressions` and handled during processing.
#
# State machine:
#   processing → delivered    (confirmed by Postmark webhook)
#   processing → bounced      (bounce notification from Postmark webhook)
#   processing → suppressed   (email on suppression list or Postmark rejection)
#   suppressed → processing   (retry after email unsuppression, via retry!)
#
# No `draft` state — draft tracking lives on MailDelivery only.
# Draft MailDeliveries have no Email children.
class MailDelivery
  class Email < ApplicationRecord
    include HasState
    include PostmarkSync
    include Retriable

    has_states :processing, :delivered, :suppressed, :bounced

    belongs_to :mail_delivery

    validates :email, presence: true

    scope :with_email, ->(email) { where("email LIKE ?", "%#{email}%") }

    before_create :check_email_suppressions
    after_create_commit -> { ProcessJob.perform_later(self) }

    def deliverable?
      email_suppression_ids.empty?
    end

    # Full processing lifecycle — builds message, delivers (or suppresses),
    # stores preview, and recomputes parent state.
    # Called by ProcessJob to keep the job as thin orchestration.
    def process!
      message = mail_delivery.build_message(email: email)

      if deliverable?
        delivered_message = message.deliver_now
        processed!(delivered_message)
        mail_delivery.store_preview_from!(delivered_message)
      else
        suppressed!
        mail_delivery.store_preview_from!(message)
      end
    rescue Postmark::InactiveRecipientError
      Scheduled::PostmarkSyncSuppressionsJob.perform_now
      suppressed!
      mail_delivery.store_preview_from!(message)
    end

    def delivered!(at:, **attrs)
      invalid_transition(:delivered) unless processing?

      update!({
        state: DELIVERED_STATE,
        delivered_at: at
      }.merge(attrs))

      mail_delivery.recompute_state!
    end

    def bounced!(at:, **attrs)
      invalid_transition(:bounced) unless processing?

      update!({
        state: BOUNCED_STATE,
        bounced_at: at
      }.merge(attrs))

      mail_delivery.recompute_state!
    end

    private

    def suppressed!
      invalid_transition(:suppressed) unless processing?

      update_columns(state: SUPPRESSED_STATE)
      mail_delivery.recompute_state!
    end

    def processed!(message)
      update_columns(
        postmark_message_id: message["X-PM-Message-Id"]&.value,
        processed_at: Time.current)
    end

    def check_email_suppressions
      suppressions = EmailSuppression.active.where(email: email).select(:id, :reason)

      self.email_suppression_ids = suppressions.map(&:id)
      self.email_suppression_reasons = suppressions.map(&:reason).uniq
    end
  end
end

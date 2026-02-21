# frozen_string_literal: true

# Handles retrying suppressed email deliveries after an email address
# is unsuppressed (e.g., admin removes a hard bounce suppression).
#
# When an EmailSuppression is lifted, recent MailDelivery::Email records
# that were blocked by that suppression can be retried. The retry
# re-checks all active suppressions, so emails blocked by multiple
# suppressions won't be sent until all are lifted.
#
# Only emails within MISSING_EMAILS_ALLOWED_PERIOD (1 week) are
# eligible — older deliveries likely have stale content.
module MailDelivery::Email::Retriable
  extend ActiveSupport::Concern

  included do
    scope :retriable_for, ->(suppression) {
      suppressed
        .where("EXISTS (SELECT 1 FROM json_each(email_suppression_ids) WHERE value = ?)", suppression.id)
        .joins(:mail_delivery)
        .merge(MailDelivery.where("mail_deliveries.created_at > ?", MailDelivery::MISSING_EMAILS_ALLOWED_PERIOD.ago))
    }
  end

  # Retries a suppressed email after its suppression has been lifted.
  # Re-checks current suppressions — if still suppressed by other active
  # suppressions, updates stored data and stays suppressed.
  # Returns true if the email was retried, false if still suppressed.
  def retry!
    invalid_transition(:retry) unless suppressed?

    fresh_suppressions = EmailSuppression.active.where(email: email).select(:id, :reason)

    if fresh_suppressions.any?
      update!(
        email_suppression_ids: fresh_suppressions.map(&:id),
        email_suppression_reasons: fresh_suppressions.map(&:reason).uniq)
      return false
    end

    update!(
      state: "processing",
      email_suppression_ids: [],
      email_suppression_reasons: [])
    MailDelivery::ProcessJob.perform_later(self)
    mail_delivery.recompute_state!
    true
  end
end

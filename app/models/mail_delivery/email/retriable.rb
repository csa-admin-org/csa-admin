# frozen_string_literal: true

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

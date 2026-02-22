# frozen_string_literal: true

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

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
    after_create_commit :enqueue_process_job

    # Same result as Member#active_emails, with outbound suppressions loaded once.
    def self.recipients_by_member_id(members)
      suppressed = EmailSuppression.outbound.active
        .where(email: members.flat_map(&:emails_array))
        .pluck(:email)
        .to_set

      members.to_h { |member|
        next [ member.id, [] ] if member.discarded?

        [ member.id, member.emails_array.reject { |email| suppressed.include?(email) } ]
      }
    end

    def self.insert_all_for!(deliveries, recipients, newsletter:)
      rows = rows_for(deliveries, recipients, newsletter: newsletter)
      insert_all!(rows) if rows.any?
    end

    def self.enqueue_process_jobs
      ActiveJob.perform_all_later(all.map { |email| ProcessJob.new(email) })
    end

    def self.rows_for(deliveries, recipients, newsletter:)
      suppressions = suppressions_by_email(recipients.values.flatten, newsletter: newsletter)

      deliveries.flat_map { |delivery|
        Array(recipients[delivery["member_id"].to_i]).map { |email|
          records = suppressions[email] || []
          {
            mail_delivery_id: delivery["id"],
            email: email,
            state: PROCESSING_STATE,
            email_suppression_ids: records.map(&:id),
            email_suppression_reasons: records.map(&:reason).uniq
          }
        }
      }
    end
    private_class_method :rows_for

    def self.suppressions_by_email(addresses, newsletter:)
      scope = EmailSuppression.active.where(email: addresses)
      scope = scope.outbound unless newsletter
      scope.select(:id, :email, :reason).group_by(&:email)
    end
    private_class_method :suppressions_by_email

    def deliverable?
      email_suppression_ids.empty?
    end

    def process!
      return unless processing?
      return unless mail_delivery

      if mail_delivery.mailable_missing?
        Rails.logger.info "MailDelivery::Email##{id}: #{mail_delivery.mailable_type} #{mail_delivery.mailable_ids} no longer exists, skipping"
        mail_delivery.destroy!
        return
      end

      message = mail_delivery.build_message(email: email)

      if deliverable?
        delivered_message = message.deliver_now
        processed!(delivered_message)
        mail_delivery.store_preview_from!(delivered_message)
        fake_delivery! if Tenant.demo?
      else
        suppressed!
        mail_delivery.store_preview_from!(message)
      end
    rescue Postmark::InactiveRecipientError
      EmailSuppression.sync_postmark!(fromdate: 1.week.ago)
      suppressed!
      mail_delivery.store_preview_from!(message)
    rescue Postmark::InvalidEmailRequestError
      suppress_invalid_address!
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

    def fake_delivery!
      return unless Tenant.demo?

      delivered!(at: Time.current)
    end

    def suppress_invalid_address!
      EmailSuppression::STREAM_IDS.each do |stream_id|
        EmailSuppression.suppress!(email, stream_id: stream_id,
          reason: "InvalidAddress", origin: "Recipient")
      end
      suppressions = EmailSuppression.active.where(email: email).select(:id, :reason)
      update_columns(
        email_suppression_ids: suppressions.map(&:id),
        email_suppression_reasons: suppressions.map(&:reason).uniq)
    end

    def enqueue_process_job
      queue = mail_delivery.session? ? :critical : :low
      ProcessJob.set(queue: queue).perform_later(self)
    end

    def check_email_suppressions
      scope = EmailSuppression.active.where(email: email)
      scope = scope.outbound unless mail_delivery.newsletter?
      suppressions = scope.select(:id, :reason)

      self.email_suppression_ids = suppressions.map(&:id)
      self.email_suppression_reasons = suppressions.map(&:reason).uniq
    end
  end
end

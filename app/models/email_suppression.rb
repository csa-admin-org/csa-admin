# frozen_string_literal: true

require "postmark_wrapper"

class EmailSuppression < ApplicationRecord
  STREAM_IDS = %w[outbound broadcast]
  REASONS = %w[HardBounce SpamComplaint ManualSuppression Forgotten]
  ORIGINS = %w[Recipient Customer Admin Sync Mailchimp]

  normalizes :email, with: ->(email) { email.downcase.strip }

  scope :active, -> { where(unsuppressed_at: nil) }
  scope :outbound, -> { where(stream_id: "outbound") }
  scope :broadcast, -> { where(stream_id: "broadcast") }
  scope :unsuppressable, -> { active.where.not(reason: "SpamComplaint") }

  validates :email, presence: true
  validates :stream_id, presence: true, inclusion: { in: STREAM_IDS }
  validates :reason, presence: true, inclusion: { in: REASONS }
  validates :origin, presence: true, inclusion: { in: ORIGINS }

  after_create_commit :notify_admins!

  def self.sync_postmark!(options = {})
    STREAM_IDS.each do |stream_id|
      PostmarkWrapper.dump_suppressions(stream_id, options).each do |suppression|
        find_or_create_by!(
          stream_id: stream_id,
          email: suppression[:email_address],
          reason: suppression[:suppression_reason],
          origin: suppression[:origin],
          created_at: suppression[:created_at])
      end
    end
  end

  def self.unsuppress!(email, stream_id:, origin: nil)
    conditions = { email: email, stream_id: stream_id, origin: origin }
    unsuppressable.where(conditions.compact).find_each(&:unsuppress!)
  end

  def self.suppress!(email, stream_id:, **attrs)
    conditions = { email: email, stream_id: stream_id }
    unless active.exists?(conditions)
      PostmarkWrapper.create_suppressions(stream_id, email.downcase)
      create!(conditions.merge(attrs))
    end
  end

  def unsuppress!
    return unless unsuppressable?

    PostmarkWrapper.delete_suppressions(stream_id, email.downcase)
    touch(:unsuppressed_at)
    retry_suppressed_deliveries!
  end

  def active?
    unsuppressed_at.nil?
  end

  def unsuppressable?
    active? && !spam_complaint?
  end

  def owners
    owners = []
    owners += Admin.with_email(email)
    owners += Member.with_email(email)
    owners += Depot.with_email(email)
    owners
  end

  def broadcast?
    stream_id == "broadcast"
  end

  def manual_suppression?
    reason == "ManualSuppression"
  end

  def spam_complaint?
    reason == "SpamComplaint"
  end

  private

  # After unsuppression, retries recent suppressed MailDelivery::Email records
  # that were blocked by this suppression. Each retry re-checks all active
  # suppressions, so emails blocked by multiple suppressions won't be sent
  # until all are lifted.
  def retry_suppressed_deliveries!
    MailDelivery::Email.retriable_for(self).find_each(&:retry!)
  end

  def notify_admins!
    return if manual_suppression?

    Admin.notify!(:new_email_suppression, email_suppression: self)
  end
end

# frozen_string_literal: true

require "securerandom"

class BankConnection::FinalizationNotification < ApplicationRecord
  include HasState

  RECIPIENTS = %w[initiating_admin ultra_admin].freeze
  DELIVERY_CLAIM_TIMEOUT = 10.minutes

  has_states :pending, :delivering, :delivered, :skipped

  belongs_to :bank_connection

  validates :event_id, :recipient, presence: true
  validates :recipient, inclusion: { in: RECIPIENTS }

  scope :dispatchable, -> {
    where(
      "state = ? OR (state = ? AND (delivery_started_at IS NULL OR delivery_started_at <= ?))",
      PENDING_STATE,
      DELIVERING_STATE,
      DELIVERY_CLAIM_TIMEOUT.ago)
  }

  after_create_commit :enqueue_delivery

  def self.create_for_finalization!(bank_connection:, event_id:)
    RECIPIENTS.map do |recipient|
      create_or_find_by!(bank_connection:, event_id:, recipient:)
    end
  end

  def self.dispatch_pending!
    dispatchable.find_each(&:enqueue_delivery)
  end

  def enqueue_delivery
    BankConnection::FinalizationNotificationJob.perform_later(id)
  rescue => error
    Rails.error.report(error, context: bank_connection.safe_context(
      operation_kind: "ebics_onboarding_finalization_notification_dispatch",
      recipient: recipient))
    false
  end

  # Email delivery is at-least-once. Duplicate queued jobs only deliver while holding the claim.
  def deliver!
    claim_token = claim_delivery!
    return false unless claim_token

    message = mail_message
    message ? deliver_message!(message, claim_token) : skip_delivery!(claim_token)
  rescue => error
    release_delivery_claim!(claim_token, error) if claim_token
    raise
  end

  private

  def claim_delivery!
    with_lock do
      return if delivered? || skipped?
      return if delivering? && !stale_delivery_claim?

      claim_token = SecureRandom.uuid
      update!(
        state: DELIVERING_STATE,
        delivery_claim_token: claim_token,
        delivery_started_at: Time.current,
        last_error_class: nil)
      claim_token
    end
  end

  def deliver_message!(message, claim_token)
    message.deliver_now
    complete_delivery!(claim_token, state: DELIVERED_STATE, delivered_at: Time.current)
  end

  def skip_delivery!(claim_token)
    complete_delivery!(claim_token, state: SKIPPED_STATE)
  end

  def complete_delivery!(claim_token, attributes)
    with_lock do
      return false unless delivery_claim_owned?(claim_token)

      update!(attributes.merge(
        delivery_claim_token: nil,
        delivery_started_at: nil,
        last_error_class: nil))
      true
    end
  end

  def release_delivery_claim!(claim_token, error)
    with_lock do
      return unless delivery_claim_owned?(claim_token)

      update!(
        state: PENDING_STATE,
        delivery_claim_token: nil,
        delivery_started_at: nil,
        last_error_class: error.class.name)
    end
  end

  def stale_delivery_claim?
    delivery_started_at.blank? || delivery_started_at <= DELIVERY_CLAIM_TIMEOUT.ago
  end

  def delivery_claim_owned?(claim_token)
    delivering? && delivery_claim_token == claim_token
  end

  def mail_message
    case recipient
    when "initiating_admin"
      admin = initiating_admin
      AdminMailer.with(admin: admin, connection: bank_connection).ebics_setup_finalized_email if admin
    when "ultra_admin"
      EBICSOnboardingMailer.with(connection: bank_connection).finalized_notification_email
    end
  end

  def initiating_admin
    status = bank_connection.status_details.to_h.dig("onboarding").to_h.deep_stringify_keys
    Admin.find_by(id: status["initiated_by_admin_id"]) ||
      Admin.find_by(email: status["initiated_by_admin_email"])
  end
end

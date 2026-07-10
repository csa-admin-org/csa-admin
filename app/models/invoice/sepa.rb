# frozen_string_literal: true

require "digest"
require "securerandom"

module Invoice::SEPA
  extend ActiveSupport::Concern

  SUBMISSION_STATES = %w[submitting submitted uncertain failed].freeze
  SubmissionPayloadDrift = Class.new(StandardError)
  SubmissionReconciliationError = Class.new(StandardError)

  included do
    belongs_to :sepa_mandate, optional: true

    scope :sepa, -> { where.not(sepa_mandate_id: nil) }
    scope :not_sepa, -> { where(sepa_mandate_id: nil) }
    scope :sepa_eq, ->(bool) { ActiveRecord::Type::Boolean.new.cast(bool) ? sepa : not_sepa }

    validates :sepa_direct_debit_submission_state,
      inclusion: { in: SUBMISSION_STATES },
      allow_nil: true

    before_validation :set_sepa_mandate, on: :create
  end

  def sepa?
    Current.org.sepa_configured? && sepa_mandate_id?
  end

  def sepa_debtor_name
    self[:sepa_debtor_name].presence || member&.billing_info(:name)
  end

  def sepa_direct_debit_pain_schema
    if Current.org.bank_connection_sepa_direct_debit_upload?
      bank_connection = Current.org.bank_connection
      return bank_connection.sepa_direct_debit_schema if bank_connection.respond_to?(:sepa_direct_debit_schema)
    end

    Billing::SEPADirectDebit::PAIN_008_001_08
  end

  def sepa_direct_debit_pain_xml(schema: sepa_direct_debit_pain_schema, message_id: nil, generated_at: nil)
    Billing::SEPADirectDebit.new(
      self,
      schema: schema,
      message_id: message_id,
      generated_at: generated_at).xml
  end

  def sepa_direct_debit_order_uploaded?
    sepa_direct_debit_order_uploaded_at?
  end

  def sepa_direct_debit_order_uploaded_by
    return unless sepa_direct_debit_order_uploaded_at?

    audits.reversed.find_change_of(:sepa_direct_debit_order_uploaded_at, from: nil)&.actor
  end

  def sepa_direct_debit_order_uploadable?
    open?
      && sepa?
      && sent?
      && !sepa_direct_debit_order_uploaded?
      && sepa_direct_debit_order_submission_retryable?
      && Current.org.bank_connection_sepa_direct_debit_upload?
  end

  def sepa_direct_debit_order_automatic_upload_due?
    return unless sepa_direct_debit_order_uploadable?

    sepa_direct_debit_order_automatic_upload_scheduled_on <= Date.current
  end

  def sepa_direct_debit_order_automatic_upload_scheduled_on
    return unless sepa_direct_debit_order_uploadable?

    (sent_at + Billing::SEPADirectDebit::AUTOMATIC_ORDER_UPLOAD_DELAY).to_date
  end

  def upload_sepa_direct_debit_order
    return if Rails.env.development?
    return unless sepa_direct_debit_order_uploadable?

    bank_connection = Current.org.bank_connection
    return unless bank_connection

    message_id, generated_at = sepa_direct_debit_order_submission_attempt
    pain_xml = sepa_direct_debit_pain_xml(message_id: message_id, generated_at: generated_at)
    ensure_sepa_direct_debit_submission_payload_matches!(pain_xml)

    submission_claimed = claim_sepa_direct_debit_order_submission(message_id, pain_xml, generated_at)
    return unless submission_claimed

    transaction_id, order_id = bank_connection.sepa_direct_debit_upload(pain_xml)
    record_sepa_direct_debit_order_submission!(transaction_id, order_id)
    Rails.event.notify(:sepa_direct_debit_order_uploaded,
      invoice_id: id,
      order_id: order_id)
    true
  rescue => e
    mark_sepa_direct_debit_order_submission_uncertain! if submission_claimed
    context = sepa_direct_debit_upload_context(error_class: e.class.name)
    Rails.error.report(e, context: context)
    Rails.event.notify(:sepa_direct_debit_order_upload_failed, **context.symbolize_keys)
    false
  end

  def confirm_sepa_direct_debit_order_not_accepted!
    with_lock do
      unless sepa_direct_debit_submission_state == "uncertain"
        raise SubmissionReconciliationError, "Only an uncertain SEPA direct debit submission can be reconciled as not accepted"
      end
      if sepa_direct_debit_order_id.present? || sepa_direct_debit_order_uploaded_at.present?
        raise SubmissionReconciliationError, "A SEPA direct debit submission with a bank order ID cannot be retried as not accepted"
      end
      unless sepa_direct_debit_submission_attempted_at? &&
          sepa_direct_debit_pain_message_id? &&
          sepa_direct_debit_pain_payload_sha256?
        raise SubmissionReconciliationError, "The uncertain SEPA direct debit submission has no complete persisted payload identity"
      end

      update!(sepa_direct_debit_submission_state: "failed")
    end
    Rails.event.notify(:sepa_direct_debit_order_confirmed_not_accepted, invoice_id: id)
    true
  end

  def sepa_direct_debit_upload_context(**attributes)
    Billing::EBICS::SafeContext.build(
      connection: Current.org.active_bank_connection,
      invoice_id: id,
      member_display_id: member&.display_id,
      **attributes)
  end

  private

  def sepa_direct_debit_order_submission_retryable?
    sepa_direct_debit_order_id.blank?
      && sepa_direct_debit_submission_state.in?([ nil, "failed" ])
  end

  def sepa_direct_debit_order_submission_attempt
    if sepa_direct_debit_submission_state == "failed"
      message_id = sepa_direct_debit_pain_message_id
      generated_at = sepa_direct_debit_submission_attempted_at
      digest = sepa_direct_debit_pain_payload_sha256

      unless message_id.present? && generated_at.present? && digest.present?
        raise SubmissionPayloadDrift, "Failed SEPA direct debit submission is missing its persisted payload identity"
      end

      [ message_id, generated_at ]
    else
      [ sepa_direct_debit_pain_message_id.presence || "CSAADMIN/#{SecureRandom.hex(11)}", Time.current ]
    end
  end

  def ensure_sepa_direct_debit_submission_payload_matches!(pain_xml)
    return unless sepa_direct_debit_submission_state == "failed"

    digest = Digest::SHA256.hexdigest(pain_xml)
    return if digest == sepa_direct_debit_pain_payload_sha256

    raise SubmissionPayloadDrift, "Failed SEPA direct debit submission payload no longer matches its persisted digest"
  end

  def claim_sepa_direct_debit_order_submission(message_id, pain_xml, generated_at)
    scope = self.class
      .where(
        id: id,
        state: Invoice::OPEN_STATE,
        sepa_direct_debit_order_id: nil,
        sepa_direct_debit_order_uploaded_at: nil,
        sepa_direct_debit_submission_state: [ nil, "failed" ])
      .where.not(sepa_mandate_id: nil, sent_at: nil)

    if sepa_direct_debit_submission_state == "failed"
      scope = scope.where(
        sepa_direct_debit_pain_message_id: message_id,
        sepa_direct_debit_pain_payload_sha256: Digest::SHA256.hexdigest(pain_xml))
    end

    scope.update_all(
      sepa_direct_debit_submission_state: "submitting",
      sepa_direct_debit_submission_attempted_at: generated_at,
      sepa_direct_debit_pain_message_id: message_id,
      sepa_direct_debit_pain_payload_sha256: Digest::SHA256.hexdigest(pain_xml),
      updated_at: Time.current) == 1
  end

  def record_sepa_direct_debit_order_submission!(transaction_id, order_id)
    update_columns(
      sepa_direct_debit_transaction_id: transaction_id,
      sepa_direct_debit_order_id: order_id,
      updated_at: Time.current)
    update!(
      sepa_direct_debit_submission_state: "submitted",
      sepa_direct_debit_order_uploaded_at: Time.current)
  end

  def mark_sepa_direct_debit_order_submission_uncertain!
    self.class
      .where(id: id, sepa_direct_debit_submission_state: "submitting")
      .update_all(sepa_direct_debit_submission_state: "uncertain", updated_at: Time.current)
  end

  def set_sepa_mandate
    self.sepa_mandate ||= member&.current_sepa_mandate if Current.org.sepa_configured? && member&.sepa?
    self[:sepa_debtor_name] ||= member&.billing_info(:name) if sepa_mandate.present?
  end
end

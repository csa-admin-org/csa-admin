# frozen_string_literal: true

module Billing
  class PaymentsProcessor
    NO_RECENT_PAYMENTS_SINCE = 6.weeks

    def self.retrieve_and_process!
      return if Rails.env.development?

      connection = Current.org.active_bank_connection
      return if connection.nil? || connection.payment_import_blocked?

      connection.runtime_adapter.process_payments!
    end

    def initialize(payments_data, raise_on_error: false)
      @payments_data = payments_data
      @raise_on_error = raise_on_error
    end

    def process!
      unless @payments_data.present?
        Rails.event.notify(:payment_processing_no_payments_data, {})
        return true
      end

      @payments_data.each do |payment_data|
        create_payment!(payment_data)
      end
      ensure_recent_payments!
      true
    end

    private

    attr_reader :raise_on_error

    def create_payment!(data)
      return unless invoice = find_invoice(data)

      attrs = data.to_h.slice(:invoice_id, :amount, :date, :fingerprint)
      payment = find_or_initialize_payment(data, attrs)
      return unless payment

      if payment.persisted? && payment.origin != data.origin
        Rails.event.notify(:payment_origin_override,
          payment_id: payment.id,
          previous_origin: payment.origin,
          **data.to_h)
      end

      payment.origin = data.origin
      payment = save_payment!(payment, data)

      if invoice.reload.overpaid?
        invoice.send_overpaid_notification_to_admins!
      end
      if payment.reversal?
        payment.send_reversal_notification_to_admins!
      end
    rescue => e
      Rails.error.report(e, context: { data: data })
      raise if raise_on_error
    end

    def find_or_initialize_payment(data, attrs)
      payment = Payment.find_or_initialize_by(attrs)
      return payment unless payment.new_record? && camt_payment?(data) && data.fingerprint.present?

      reconciled_payment = reconcile_legacy_camt_payment(data)
      return if reconciled_payment == :ambiguous

      reconciled_payment || payment
    end

    def reconcile_legacy_camt_payment(data)
      matching_payments = matching_camt_payments(data)
      legacy_payments = matching_payments.where(fingerprint: nil).limit(2).to_a
      return if legacy_payments.empty?

      payments_count = matching_payments.count
      return claim_legacy_camt_payment(legacy_payments.sole, data) if payments_count == 1 && legacy_payments.one?

      report_ambiguous_legacy_camt_payments(data, matching_payments.limit(20).to_a, payments_count)
      :ambiguous
    end

    def claim_legacy_camt_payment(payment, data)
      claimed = Payment.where(id: payment.id, fingerprint: nil).update_all(
        fingerprint: data.fingerprint,
        updated_at: Time.current)
      return Payment.find(payment.id) if claimed == 1
      return existing if (existing = Payment.find_by(fingerprint: data.fingerprint))

      report_ambiguous_legacy_camt_payments(data, [ payment ], 1)
      :ambiguous
    end

    def matching_camt_payments(data)
      Payment.where(
        origin: %w[camt.053 camt.054],
        invoice_id: data.invoice_id,
        amount: data.amount,
        date: data.date)
    end

    def report_ambiguous_legacy_camt_payments(data, payments, payments_count)
      Rails.event.notify(:payment_processing_legacy_camt_fingerprint_ambiguous,
        origin: data.origin,
        invoice_id: data.invoice_id,
        amount: data.amount,
        date: data.date,
        fingerprint: data.fingerprint,
        payments_count: payments_count,
        payment_ids: payments.map(&:id))
    end

    def camt_payment?(data)
      data.origin.in?(%w[camt.053 camt.054])
    end

    def save_payment!(payment, data)
      payment.save!
      payment
    rescue ActiveRecord::RecordNotUnique
      raise unless data.fingerprint.present?

      payment = Payment.find_by(fingerprint: data.fingerprint)
      raise unless payment

      payment
    end

    def find_invoice(data)
      unless data.member_id && Member.exists?(data.member_id)
        Rails.event.notify(:payment_processing_unknown_member, **data.to_h)
        return
      end

      invoices = Member.find(data.member_id).invoices

      unless invoice = invoices.find_by(id: data.invoice_id)
        Rails.event.notify(:payment_processing_unknown_invoice, **data.to_h)
        return
      end

      invoice
    end

    def ensure_recent_payments!
      if Invoice.not_canceled.sent.where("created_at > ?", NO_RECENT_PAYMENTS_SINCE.ago).any?
          && Payment.import.where("created_at > ?", NO_RECENT_PAYMENTS_SINCE.ago).none?
        if last_payment = Payment.import.reorder(:created_at).last
          Rails.error.unexpected("No recent payment error", context: {
            last_payment_id: last_payment.id,
            last_payment_date: last_payment.date,
            last_payment_created_at: last_payment.created_at
          })
        end
      end
    end
  end
end

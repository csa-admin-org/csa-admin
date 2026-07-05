# frozen_string_literal: true

module Billing
  class PaymentsProcessor
    NO_RECENT_PAYMENTS_SINCE = 6.weeks

    def self.retrieve_and_process!
      return if Rails.env.development?

      Current.org.bank_connection&.process_payments!
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
      payment = Payment.find_or_initialize_by(attrs)

      if payment.persisted? && payment.origin != data.origin
        Rails.event.notify(:payment_origin_override,
          payment_id: payment.id,
          previous_origin: payment.origin,
          **data.to_h)
      end

      payment.origin = data.origin
      payment.save!

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

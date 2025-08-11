# frozen_string_literal: true

module Billing
  class PaymentsProcessor
    NoRecentPaymentsError = Class.new(StandardError)

    NO_RECENT_PAYMENTS_SINCE = 6.weeks

    def self.retrieve_and_process!
      return if Rails.env.development?
      return unless Current.org.bank_connection?

      payments_data = Current.org.bank_connection.payments_data
      new(payments_data).process!
    end

    def initialize(payments_data)
      @payments_data = payments_data
    end

    def process!
      @payments_data.each do |payment_data|
        create_payment!(payment_data)
      end
      ensure_recent_payments!
      true
    end

    private

    def create_payment!(data)
      return if Payment.where(fingerprint: data.fingerprint).exists?
      return unless invoice = find_invoice(data)

      Payment.create!(
        invoice: invoice,
        amount: data.amount,
        date: data.date,
        fingerprint: data.fingerprint)

      if invoice.reload.overpaid?
        invoice.send_overpaid_notification_to_admins!
      end
    rescue => e
      Error.report(e, data: data)
    end

    def find_invoice(data)
      if data.member_id && !Member.exists?(data.member_id)
        log(:unknown_member, data)
        return
      end

      invoices =
        if data.member_id
          Member.find(data.member_id).invoices
        else
          Invoice.all
        end

      unless invoice = invoices.find_by(id: data.invoice_id)
        log(:unknown_invoice, data)
        return
      end

      invoice
    end

    def ensure_recent_payments!
      if Invoice.not_canceled.sent.where("created_at > ?", NO_RECENT_PAYMENTS_SINCE.ago).any? &&
          Payment.auto.where("created_at > ?", NO_RECENT_PAYMENTS_SINCE.ago).none?
        if last_payment = Payment.auto.reorder(:created_at).last
          Error.notify("No recent payment error",
            last_payment_id: last_payment.id,
            last_payment_date: last_payment.date,
            last_payment_created_at: last_payment.created_at)
        end
      end
    end

    def log(event, data)
      Rails.logger.info { "payment_processing #{event} #{data.fingerprint}" }
    end
  end
end

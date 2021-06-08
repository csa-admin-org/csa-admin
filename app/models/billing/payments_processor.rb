module Billing
  class PaymentsProcessor
    NoRecentPaymentsError = Class.new(StandardError)

    NO_RECENT_PAYMENTS_SINCE = 4.weeks

    def self.process!
      return if Rails.env.development?

      if payments_data = provider&.payments_data
        new(payments_data).process!
      end
    end

    def self.provider
      if ebics_credentials = Current.acp.credentials(:ebics)
        EBICS.new(ebics_credentials)
      elsif bas_credentials = Current.acp.credentials(:bas)
        BAS.new(bas_credentials)
      end
    end

    def initialize(payments_data)
      @payments_data = payments_data
    end

    def process!
      @payments_data.each do |payment_data|
        create_payment!(payment_data)
      end
      ensure_recent_payments!
    end

    private

    def create_payment!(data)
      return if Payment.with_deleted.where(isr_data: data.isr_data).exists?

      invoice = Invoice.find(data.invoice_id)

      Payment.create!(
        invoice: invoice,
        amount: data.amount,
        date: data.date,
        isr_data: data.isr_data)

      if invoice.reload.overpaid?
        invoice.send_overpaid_notification_to_admins!
      end
    rescue => e
      ExceptionNotifier.notify(e, data)
      Sentry.capture_exception(e, extra: { data: data })
    end

    def ensure_recent_payments!
      if Invoice.not_canceled.sent.where('created_at > ?', NO_RECENT_PAYMENTS_SINCE.ago).any? &&
          Payment.isr.where('created_at > ?', NO_RECENT_PAYMENTS_SINCE.ago).none?
        if last_payment = Payment.isr.reorder(:created_at).last
          ExceptionNotifier.notify(NoRecentPaymentsError.new,
            last_payment_id: last_payment.id,
            last_payment_date: last_payment.date,
            last_payment_created_at: last_payment.created_at)
          Sentry.capture_message('No recent payment error', extra: {
            last_payment_id: last_payment.id,
            last_payment_date: last_payment.date,
            last_payment_created_at: last_payment.created_at
          })
        end
      end
    end
  end
end

class PaymentsProcessor
  InvoiceIsrBalanceUpdateError = Class.new(StandardError)
  NoRecentPaymentsError = Class.new(StandardError)

  NO_RECENT_PAYMENTS_SINCE = 4.weeks

  def initialize(provider)
    @provider = provider
  end

  def process
    @provider.payments_data.each do |payment_data|
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
      notify_admins_about_overpaid_invoice(invoice)
    end
  rescue => e
    ExceptionNotifier.notify(e, data)
  end

  def notify_admins_about_overpaid_invoice(invoice)
    Admin.notification('invoice_overpaid').find_each do |admin|
      Email.deliver_now(:admin_invoice_overpaid, admin, invoice)
    end
  end

  def ensure_recent_payments!
    if Invoice.not_canceled.sent.where('created_at > ?', NO_RECENT_PAYMENTS_SINCE.ago).any? &&
        Payment.isr.where('created_at > ?', NO_RECENT_PAYMENTS_SINCE.ago).none?
      if last_payment = Payment.isr.reorder(:created_at).last
        ExceptionNotifier.notify(NoRecentPaymentsError.new,
          last_payment_id: last_payment.id,
          last_payment_date: last_payment.date,
          last_payment_created_at: last_payment.created_at)
      end
    end
  end
end

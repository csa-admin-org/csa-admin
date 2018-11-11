class PaymentsProcessor
  InvoiceIsrBalanceUpdateError = Class.new(StandardError)
  NoRecentPaymentsError = Class.new(StandardError)

  NO_RECENT_PAYMENTS_SINCE = 3.weeks

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

    Payment.create!(
      invoice: Invoice.find(data.invoice_id),
      amount: data.amount,
      date: data.date,
      isr_data: data.isr_data)

  rescue => ex
    ExceptionNotifier.notify(ex, data)
  end

  def ensure_recent_payments!
    if Payment.isr.where('date > ?', NO_RECENT_PAYMENTS_SINCE.ago).none?
      last_payment = Payment.isr.last
      ExceptionNotifier.notify(NoRecentPaymentsError.new,
        last_payment_id: last_payment.id,
        last_payment_date: last_payment.date)
    end
  end
end

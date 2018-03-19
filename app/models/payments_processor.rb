class PaymentsProcessor
  InvoiceIsrBalanceUpdateError = Class.new(StandardError)

  def initialize(provider)
    @provider = provider
  end

  def process
    @provider.payments_data.each do |payment_data|
      create_payment!(payment_data)
    end
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
    ExceptionNotifier.notify_exception(ex, data: data)
  end
end

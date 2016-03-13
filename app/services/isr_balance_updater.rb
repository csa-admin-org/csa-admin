class IsrBalanceUpdater
  InvoiceIsrBalanceUpdateError = Class.new(StandardError)

  attr_reader :raiffeisen

  def initialize
    @raiffeisen = Raiffeisen.new
  end

  def update_all
    isr_data = raiffeisen.get_isr_data(:all)
    isr_data.each { |isr| update_invoice(isr) }
  end

  private

  def update_invoice(isr)
    invoice = Invoice.find(isr[:invoice_id])
    invoice.isr_balance_data[isr[:data]] ||=
      isr.slice(:amount).merge(date: Time.zone.today)
    invoice.save!
  rescue => ex
    report_error(ex, isr)
  end

  def report_error(ex, isr)
    error = InvoiceIsrBalanceUpdateError.new(
      "Issue with invoice id: #{isr[:invoice_id]}, " \
      "error: #{ex.message} " \
      "backtrace: #{ex.backtrace.inspect}"
    )
    ExceptionNotifier.notify_exception(error)
  end
end

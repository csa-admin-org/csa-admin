class IsrBalanceUpdater
  InvoiceIsrBalanceUpdateError = Class.new(StandardError)

  attr_reader :raiffeisen

  def initialize
    @raiffeisen = Raiffeisen.new
  end

  def update_all
    raiffeisen
      .get_isr_data(:all)
      .group_by { |isr| isr.delete(:invoice_id) }
      .each { |invoice_id, isrs| update_invoice(invoice_id, isrs) }
  end

  private

  def update_invoice(invoice_id, isrs)
    invoice = Invoice.find(invoice_id)
    data = isrs.map.with_index { |isr, index|
      ["#{index}-#{isr[:data]}", isr[:amount]]
    }.to_h
    invoice.update!(isr_balance_data: data)
  rescue => ex
    report_error(ex, invoice_id)
  end

  def report_error(ex, invoice_id)
    error = InvoiceIsrBalanceUpdateError.new(
      "Issue with invoice id: #{invoice_id}, " \
      "error: #{ex.message} " \
      "backtrace: #{ex.backtrace.inspect}"
    )
    ExceptionNotifier.notify_exception(error)
  end
end

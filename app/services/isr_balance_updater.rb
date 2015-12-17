class IsrBalanceUpdater
  attr_reader :raiffeisen

  def initialize
    @raiffeisen = Raiffeisen.new
  end

  def update_all
    isr_data = raiffeisen.get_isr_data(:new)
    isr_data.each { |isr| update_invoice(isr) }
  end

  private

  def update_invoice(isr)
    invoice = Invoice.find(isr[:invoice_id])
    invoice.isr_balance_data[isr[:data]] =
      isr.slice(:amount).merge(date: Time.zone.today)
    invoice.save!
  rescue => ex
    ExceptionNotifier.notify_exception(ex)
  end
end

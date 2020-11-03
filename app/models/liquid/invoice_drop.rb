class Liquid::InvoiceDrop < Liquid::Drop
  def initialize(invoice)
    @invoice = invoice
  end

  def number
    @invoice.id
  end
end

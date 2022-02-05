class Liquid::InvoiceDrop < Liquid::Drop
  include NumbersHelper

  private *NumbersHelper.public_instance_methods
  private *ActiveSupport::NumberHelper.instance_methods

  def initialize(invoice)
    @invoice = invoice
  end

  def number
    @invoice.id
  end

  def date
    I18n.l(@invoice.date)
  end

  def state
    @invoice.state
  end

  def object_type
    @invoice.object_type
  end

  def object_number
    @invoice.object_id
  end

  def only_partially_paid
    @invoice.missing_amount < @invoice.amount
  end

  def amount
    cur(@invoice.amount)
  end

  def missing_amount
    cur(@invoice.missing_amount)
  end

  def overdue_notices_count
    @invoice.overdue_notices_count
  end
end

# frozen_string_literal: true

class Liquid::PaymentDrop < Liquid::Drop
  include NumbersHelper

  private(*NumbersHelper.public_instance_methods)
  private(*ActiveSupport::NumberHelper.instance_methods)

  def initialize(payment)
    @payment = payment
  end

  def invoice
    return unless @payment.invoice_id?

    Liquid::InvoiceDrop.new(@payment.invoice)
  end

  def id
    @payment.id
  end

  def date
    I18n.l(@payment.date)
  end

  def state
    @payment.state
  end

  def type
    @payment.type
  end

  def amount
    ccur(@payment, :amount)
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .payment_url(@payment.id, {}, host: Current.org.admin_url)
  end
end

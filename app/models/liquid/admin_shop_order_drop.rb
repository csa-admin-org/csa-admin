# frozen_string_literal: true

class Liquid::AdminShopOrderDrop < Liquid::Drop
  include NumbersHelper

  private(*NumbersHelper.public_instance_methods)
  private(*ActiveSupport::NumberHelper.instance_methods)

  def initialize(order)
    @order = order
  end

  def id
    @order.id
  end

  def delivery_date
    I18n.l(@order.delivery_date, format: :long)
  end

  def amount
    cur(@order.amount)
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .shop_order_url(@order.id, host: Current.org.admin_url)
  end
end

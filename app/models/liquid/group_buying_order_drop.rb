class Liquid::GroupBuyingOrderDrop < Liquid::Drop
  def initialize(order)
    @order = order
  end

  def id
    @order.id
  end

  def delivery
    Liquid::GroupBuyingDeliveryDrop.new(@order.delivery)
  end

  def member
    Liquid::MemberDrop.new(@order.member)
  end

  def admin_url
    Rails
      .application
      .routes
      .url_helpers
      .group_buying_order_url(@order, {}, host: Current.acp.email_default_host)
  end
end

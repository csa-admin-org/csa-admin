ActiveAdmin.register Shop::OrderItem do
  menu false

  filter :delivery, as: :select, collection: -> { Delivery.shop_open }

  includes :product_variant, { order: %i[member delivery], product: :producer }
  csv do
    column(:delivery) { |oi| oi.order.delivery.date }
    column(:member) { |oi| oi.order.member.name }
    column(:member_id) { |oi| oi.order.member_id }
    column(:order_date) { |oi| oi.order.date }
    column(:order_state) { |oi| oi.order.state_i18n_name    }
    column(:order_id)
    column(:producer) { |oi| oi.product.producer.name }
    column(:product) { |oi| oi.product.name }
    column(:product_variant) { |o| o.product_variant.name }
    column(:quantity)
    column(:item_price) { |oi| cur oi.item_price }
    column(:amount) { |oi| cur oi.amount }
  end

  controller do
    def scoped_collection
      super.joins(:order).where.not(shop_orders: { state: :cart })
    end

    def csv_filename
      delivery = Delivery.find(params[:q][:delivery_id_eq])
      [
        Shop::Order.model_name.human(count: 2).downcase.dasherize.delete(' '),
        Shop::OrderItem.model_name.human(count: 2).downcase.dasherize.delete(' '),
        Delivery.model_name.human.downcase.dasherize.delete(' '),
        delivery.date.to_s(:default)
      ].join('-') + '.csv'
    end
  end

  config.sort_order = 'order_id'
end

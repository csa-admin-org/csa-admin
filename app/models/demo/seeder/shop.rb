# frozen_string_literal: true

module Demo::Seeder::Shop
  extend ActiveSupport::Concern

  private

  def seed_shop!
    log "Seeding shop..."
    return if @shop_products.blank? || @active_members.blank?

    seed_coming_shop_orders!
    seed_historical_shop_orders!
  end

  def seed_coming_shop_orders!
    shop_deliveries = Delivery.where(shop_open: true).order(:date)
    delivery = shop_deliveries.coming.first || shop_deliveries.where(date: Date.current..).first
    return unless delivery

    @active_members.sample([ @active_members.size / 2, 3 ].max).each do |member|
      order = build_shop_order(member, delivery, quantity: rand(1..3))
      next unless order

      order.save!
      order.confirm! if rand < 0.8
    end
  end

  def seed_historical_shop_orders!
    Delivery.where(shop_open: true).where(date: ...Date.current).order(:date).each do |delivery|
      members = members_with_basket_on(delivery)
      next if members.empty?

      members.sample([ 4, members.size ].min).each do |member|
        next if ::Shop::Order.exists?(member: member, delivery: delivery)

        seed_historical_shop_order!(member, delivery)
      end
    end
  end

  def seed_historical_shop_order!(member, delivery)
    order = build_shop_order(member, delivery, quantity: 1)
    return unless order

    order.save!
    order.confirm!
    invoice = order.invoice!
    invoice.update_columns(date: delivery.date, sent_at: delivery.date)
    invoice.process!(send_email: false)
    invoice.reload
    payment_date = [ delivery.date + rand(5..20).days, Date.current ].min
    Payment.create!(
      member: member,
      invoice: invoice,
      amount: invoice.amount,
      date: payment_date,
      origin: "camt")
  end

  def build_shop_order(member, delivery, quantity:)
    return if ::Shop::Order.exists?(member: member, delivery: delivery)

    order = ::Shop::Order.new(member: member, delivery: delivery, state: ::Shop::Order::CART_STATE)
    @shop_products.sample(rand(1..3)).each do |product|
      variant = product.variants.available.sample
      next unless variant
      next if variant.out_of_stock?

      max_qty = [ quantity, variant.stock ].min
      next unless max_qty.positive?

      order.items.build(
        product: product,
        product_variant: variant,
        item_price: variant.price,
        quantity: max_qty)
    end
    order.items.any? ? order : nil
  end
end

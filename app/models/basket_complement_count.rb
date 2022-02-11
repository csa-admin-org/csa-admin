class BasketComplementCount
  def self.all(delivery)
    BasketComplement
      .all
      .map { |c| new(c, delivery) }
      .select { |c| c.count.positive? }
  end

  def initialize(complement, delivery)
    @complement = complement
    @delivery = delivery
  end

  def title
    @complement.name
  end

  def memberships_count
    @memberships_count ||=
      @delivery
        .baskets
        .not_absent
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement_id: @complement.id })
        .sum('baskets_basket_complements.quantity')
  end

  def shop_orders_count
    return 0 unless Current.acp.feature?('shop')

    @shop_orders_count ||=
      @delivery
        .shop_orders
        .joins(items: :product)
        .where(shop_products: { basket_complement_id: @complement.id })
        .sum('shop_order_items.quantity')
  end

  def count
    memberships_count + shop_orders_count
  end
end

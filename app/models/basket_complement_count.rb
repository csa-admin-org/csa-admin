class BasketComplementCount
  def self.all(delivery, scope: nil)
    BasketComplement
      .all
      .map { |c| new(c, delivery, scope: scope) }
      .select { |c| c.count.positive? }
  end

  def initialize(complement, delivery, scope: nil)
    @complement = complement
    @delivery = delivery
    @scope = scope || :not_absent
  end

  def title
    @complement.name
  end

  def memberships_count
    @memberships_count ||=
      @delivery
        .baskets
        .send(@scope)
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement_id: @complement.id })
        .sum('baskets_basket_complements.quantity')
  end

  def shop_orders_count
    return 0 unless Current.acp.feature?('shop')
    return 0 if @scope == :absent

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

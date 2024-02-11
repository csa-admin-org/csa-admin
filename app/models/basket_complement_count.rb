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
    @scope = scope || :active
  end

  def title
    @complement.name
  end

  def memberships_count
    @memberships_count ||=
      @delivery
        .baskets
        .send(@scope)
        .complement_count(@complement)
  end

  def shop_orders_count
    return 0 unless Current.acp.feature?("shop")
    return 0 if @scope == :absent

    @shop_orders_count ||= @delivery.shop_orders.all_without_cart.complement_count(@complement)
  end

  def count
    memberships_count + shop_orders_count
  end
end

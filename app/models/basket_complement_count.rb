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

  def count
    @count ||=
      @delivery
        .baskets
        .joins(:baskets_basket_complements)
        .where(baskets_basket_complements: { basket_complement_id: @complement.id })
        .count
  end
end

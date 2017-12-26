class DistributionCount
  def self.all(next_delivery)
    Distribution.all.map { |dist| new(dist, next_delivery) }
  end

  def initialize(distribution, next_delivery)
    @distribution = distribution
    @next_delivery = next_delivery
    @baskets = distribution.baskets.where(delivery_id: next_delivery.id)
    # eager load for the cache
    count
    baskets_count
    basket_sizes_count
  end

  def title
    @distribution.name
  end

  def count
    @count ||= @baskets.size
  end

  def baskets_count
    @baskets_count ||= basket_sizes_count.join(' / ')
  end

  def basket_sizes_count
    @basket_sizes_count ||= BasketSize.all.map { |bs|
      @baskets.count { |m| m.basket_size_id == bs.id }
    }
  end
end

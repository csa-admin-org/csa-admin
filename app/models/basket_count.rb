class BasketCount
  def self.all(next_delivery)
    basket_size_ids = BasketSize.pluck(:id)
    Distribution
      .select(:name, :id)
      .map { |dist| new(dist, next_delivery.id, basket_size_ids) }
      .select { |c| c.count.positive? }
  end

  def initialize(distribution, delivery_id, basket_size_ids)
    @distribution = distribution
    @basket_size_ids = basket_size_ids
    @baskets = distribution.baskets.not_absent.where(delivery_id: delivery_id)
  end

  def title
    @distribution.name
  end

  def distribution_id
    @distribution.id
  end

  def count
    @count ||= @baskets.count
  end

  def baskets_count
    @baskets_count ||= basket_sizes_count.join(' / ')
  end

  def basket_sizes_count
    @basket_sizes_count ||=
      @basket_size_ids.map { |id| @baskets.where(basket_size_id: id).count }
  end
end

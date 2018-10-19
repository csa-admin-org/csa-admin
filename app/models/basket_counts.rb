class BasketCounts
  def initialize(delivery, distribution_ids = nil)
    @delivery = delivery
    @basket_size_ids = BasketSize.pluck(:id)
    @distribution_ids = distribution_ids || Distribution.pluck(:id)
  end

  def all
    @all ||= Distribution
      .where(id: @distribution_ids)
      .select(:name, :id)
      .map { |dist| BasketCount.new(dist, @delivery.id, @basket_size_ids) }
      .select { |c| c.count.positive? }
  end

  def present?
    all.present?
  end

  def sum
    all.sum(&:count)
  end

  def sum_detail
    @basket_size_ids.map { |id| sum_basket_size(id) }.join(' / ')
  end

  def sum_basket_size(basket_size_id)
    i = @basket_size_ids.index(basket_size_id)
    all.sum { |c| c.basket_sizes_count[i] }
  end

  class BasketCount
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
      @count ||= @baskets.sum(:quantity)
    end

    def baskets_count
      @baskets_count ||= basket_sizes_count.join(' / ')
    end

    def basket_sizes_count
      @basket_sizes_count ||=
        @basket_size_ids.map { |id| @baskets.where(basket_size_id: id).sum(:quantity) }
    end
  end
end

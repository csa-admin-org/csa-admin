class BasketCounts
  def initialize(delivery, depot_ids = nil)
    @delivery = delivery
    @basket_size_ids = BasketSize.pluck(:id)
    @depot_ids = depot_ids || Depot.pluck(:id)
  end

  def all
    @all ||= Depot
      .where(id: @depot_ids)
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
    def initialize(depot, delivery_id, basket_size_ids)
      @depot = depot
      @basket_size_ids = basket_size_ids
      @baskets = depot.baskets.not_absent.where(delivery_id: delivery_id)
    end

    def title
      @depot.name
    end

    def depot_id
      @depot.id
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

class BasketCounts
  attr_reader :depots

  def initialize(delivery, depot_ids)
    @delivery = delivery
    @basket_size_ids = @delivery.basket_sizes.pluck(:id)
    @depots = Depot.where(id: (Array(depot_ids) & delivery.baskets.pluck(:depot_id).uniq))
  end

  def all
    @all ||= @depots
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
    attr_reader :depot

    def initialize(depot, delivery_id, basket_size_ids)
      @depot = depot
      @basket_size_ids = basket_size_ids
      @baskets = depot.baskets.not_absent.where(delivery_id: delivery_id)
      @absent_baskets = depot.baskets.absent.where(delivery_id: delivery_id)
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

    def absent_count
      @absent_count ||= @absent_baskets.sum(:quantity)
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

class BasketCounts
  attr_reader :depots

  def initialize(delivery, depot_ids, scope: nil)
    @delivery = delivery
    @basket_size_ids = @delivery.basket_sizes.pluck(:id)
    @baskets = @delivery.baskets.send(scope || :not_absent).to_a
    @shop_orders = @delivery.shop_orders.all_without_cart.to_a
    used_depot_ids = (@baskets.map(&:depot_id) + @shop_orders.map(&:depot_id)).uniq
    @depots = Depot.where(id: (Array(depot_ids) & used_depot_ids))
  end

  def all
    @all ||= @depots
      .select(:name, :id)
      .map { |depot| BasketCount.new(depot, @baskets, @basket_size_ids, @shop_orders) }
      .select { |c| c.count.positive? || c.shop_orders_count.positive? }
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
    return 0 unless i

    all.sum { |c| c.basket_sizes_count[i] }
  end

  def sum_shop_orders
    @sum_shop_orders ||= @shop_orders.size
  end

  class BasketCount
    include ActionView::Helpers::UrlHelper

    attr_reader :depot

    def initialize(depot, baskets, basket_size_ids, shop_orders)
      @depot = depot
      @baskets = baskets.select { |b| b.depot_id == depot.id }
      @basket_size_ids = basket_size_ids
      @shop_orders = shop_orders.select { |so| so.depot_id == depot.id }
    end

    def title
      url_helpers = Rails.application.routes.url_helpers
      link_to @depot.name, url_helpers.depot_path(@depot)
    end

    def depot_id
      @depot.id
    end

    def count
      @count ||= @baskets.sum(&:quantity)
    end

    def baskets_count
      @baskets_count ||= basket_sizes_count.join(' / ')
    end

    def basket_sizes_count
      @basket_sizes_count ||=
        @basket_size_ids.map { |id| @baskets.select { |b| b.basket_size_id == id }.sum(&:quantity) }
    end

    def shop_orders_count
      @shop_orders_count ||= @shop_orders.size
    end
  end
end

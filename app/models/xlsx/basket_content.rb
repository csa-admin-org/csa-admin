# frozen_string_literal: true

module XLSX
  class BasketContent < Base
    include BasketContentsHelper

    def initialize(delivery)
      @delivery = delivery
      @basket_sizes = delivery.basket_sizes.paid.ordered
      @basket_contents =
        @delivery
          .basket_contents
          .joins(:product)
          .includes(:depots, :basketcontents_depots)
          .merge(::BasketContent::Product.order_by_name)

      build_summary_worksheet
      delivery.depots.each do |depot|
        baskets = depot.baskets.active.where(delivery_id: @delivery)
        if baskets.sum(:quantity) > 0
          build_depot_worksheet(depot, baskets)
        end
      end
    end

    def filename
      [
        ::BasketContent.model_name.human(count: 2),
        @delivery.display_number,
        @delivery.date.strftime("%Y%m%d")
      ].join("-") + ".xlsx"
    end

    private

    def build_summary_worksheet
      add_worksheet I18n.t("delivery.summary")

      # Preload basket counts once for all basket contents
      preload_baskets_counts(@basket_contents)

      add_product_columns(@basket_contents)
      add_unit_columns(@basket_contents)
      add_unit_price_columns(@basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:quantity),
        @basket_contents.map { |bc| bc.quantity })
      @basket_sizes.each do |basket_size|
        add_column(
          "#{basket_size.name} - #{Basket.model_name.human(count: 2)}",
          @basket_contents.map { |bc| bc.baskets_count(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_quantity)}",
          @basket_contents.map { |bc| bc.basket_quantity(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_total_quantity)}",
          @basket_contents.map { |bc| bc.baskets_count(basket_size) * bc.basket_quantity(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:price)}",
          @basket_contents.map { |bc|
            display_price bc.unit_price, bc.basket_quantity(basket_size)
          })
      end
      add_column(
        Depot.model_name.human(count: 2),
        @basket_contents.map { |bc| display_depots(bc.depots) })
    end

    def build_depot_worksheet(depot, baskets)
      add_worksheet(depot.name)

      basket_contents = @basket_contents.for_depot(depot)

      # Preload basket counts scoped to this depot
      depot_counts = baskets.group(:basket_size_id).sum(:quantity)
      basket_contents.each do |bc|
        bc.baskets_counts_hash = depot_counts.slice(*bc.basket_size_ids)
      end

      add_product_columns(basket_contents)
      add_unit_columns(basket_contents)
      add_unit_price_columns(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:quantity),
        basket_contents.map { |bc|
          bc.basket_size_ids.sum do |basket_size_id|
            baskets_count = baskets.where(basket_size_id: basket_size_id).sum(:quantity)
            baskets_count * bc.basket_quantity(basket_size_id)
          end
        })
      @basket_sizes.each do |basket_size|
        baskets_count = baskets.where(basket_size_id: basket_size.id).sum(:quantity)
        add_column(
          "#{basket_size.name} - #{Basket.model_name.human(count: 2)}",
          basket_contents.map { |bc| baskets_count if bc.baskets_count(basket_size).positive? })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_quantity)}",
          basket_contents.map { |bc| bc.basket_quantity(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_total_quantity)}",
          basket_contents.map { |bc|
            bc.baskets_count(basket_size).to_i > 0 ? baskets_count * bc.basket_quantity(basket_size) : nil
          })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:price)}",
          basket_contents.map { |bc|
            display_price bc.unit_price, bc.basket_quantity(basket_size)
          })
      end
    end

    def preload_baskets_counts(basket_contents)
      # Single query: group by (depot_id, basket_size_id) so each BC can
      # filter by its own depot_ids without extra queries.
      raw_counts = @delivery.baskets.active
        .where(basket_size_id: BasketSize.paid.pluck(:id))
        .group(:depot_id, :basket_size_id)
        .sum(:quantity)
      basket_contents.each do |bc|
        bc_depot_ids = bc.depot_ids
        bc_basket_size_ids = bc.basket_size_ids
        merged = Hash.new(0)
        raw_counts.each do |(depot_id, bs_id), count|
          merged[bs_id] += count if bc_depot_ids.include?(depot_id) && bc_basket_size_ids.include?(bs_id)
        end
        bc.baskets_counts_hash = merged
      end
    end

    def add_product_columns(basket_contents)
      add_column(
        ::BasketContent::Product.model_name.human(count: 2),
        basket_contents.map { |bc| bc.product.name })
    end

    def add_unit_columns(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:unit),
        basket_contents.map { |bc| I18n.t("units.#{bc.unit}") })
    end

    def add_unit_price_columns(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:unit_price),
        basket_contents.map { |bc| bc.unit_price })
    end
  end
end

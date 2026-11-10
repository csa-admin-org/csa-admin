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
          .includes(:depots, :basketcontents_depots, product: :producer)
          .merge(::BasketContent::Product.order_by_name)

      build_summary_worksheet
      delivery.depots.each do |depot|
        baskets = depot.baskets.active.where(delivery_id: @delivery)
        if baskets.sum(:quantity) > 0
          build_depot_worksheet(depot, baskets)
        end
      end
      build_producers_worksheet
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
      add_quantity_column(@basket_contents) { |bc| bc.quantity }
      @basket_sizes.each do |basket_size|
        add_size_columns(basket_size, @basket_contents)
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
      add_quantity_column(basket_contents) { |bc| depot_quantity(bc, baskets) }
      @basket_sizes.each do |basket_size|
        add_size_columns(basket_size, basket_contents, baskets.where(basket_size_id: basket_size.id).sum(:quantity))
      end
    end

    def build_producers_worksheet
      rows = @delivery.basket_content_producer_prices
      return if rows.empty?

      add_worksheet(Producer.model_name.human(count: 2))
      add_column(
        Producer.model_name.human,
        rows.map { |row| row.producer.name } + [ I18n.t("attributes.total") ])
      add_column(
        I18n.t("basket_content.producers.amount"),
        rows.map { |row| money(row.price) } + [ money(rows.sum(&:price)) ],
        align: "right",
        min_width: 12,
        format: money_format)
      add_column(
        I18n.t("attributes.amount_percentage"),
        rows.map { |row| row.percentage / 100.0 } + [ 1 ],
        align: "right",
        format: percentage_format)
      @worksheet.change_row_bold(rows.size + 1, true)
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
      add_column(
        ::Producer.model_name.human,
        basket_contents.map { |bc| bc.product.producer&.name })
    end

    def add_unit_columns(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:unit),
        basket_contents.map { |bc| I18n.t("units.#{bc.unit}.flex") })
    end

    def add_unit_price_columns(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:unit_price),
        basket_contents.map { |bc| money(bc.unit_price) },
        align: "right",
        min_width: 12,
        format: money_format)
    end

    def add_quantity_column(basket_contents)
      add_column(
        ::BasketContent.human_attribute_name(:quantity),
        basket_contents.map { |bc| quantity(yield(bc)) },
        align: "right",
        format: quantity_format)
    end

    def add_size_columns(basket_size, basket_contents, depot_count = nil)
      add_column(
        "#{basket_size.name} - #{Basket.model_name.human(count: 2)}",
        basket_contents.map { |bc| count(size_count(bc, basket_size, depot_count)) },
        align: "right",
        format: count_format)
      add_column(
        "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_quantity)}",
        basket_contents.map { |bc| quantity(bc.basket_quantity(basket_size)) },
        align: "right",
        format: quantity_format)
      add_column(
        "#{basket_size.name} - #{::BasketContent.human_attribute_name(:basket_total_quantity)}",
        basket_contents.map { |bc| quantity(size_total(bc, basket_size, depot_count)) },
        align: "right",
        format: quantity_format)
      add_column(
        "#{basket_size.name} - #{::BasketContent.human_attribute_name(:price)}",
        basket_contents.map { |bc| money_price(bc.unit_price, bc.basket_quantity(basket_size)) },
        align: "right",
        min_width: 12,
        format: money_format)
    end

    def size_count(basket_content, basket_size, depot_count)
      return basket_content.baskets_count(basket_size) if depot_count.nil?

      basket_content.baskets_count(basket_size).positive? ? depot_count : 0
    end

    def size_total(basket_content, basket_size, depot_count)
      BigDecimal(size_count(basket_content, basket_size, depot_count).to_s) *
        BigDecimal(basket_content.basket_quantity(basket_size).to_s)
    end

    def depot_quantity(basket_content, baskets)
      basket_content.basket_size_ids.sum do |basket_size_id|
        baskets_count = baskets.where(basket_size_id: basket_size_id).sum(:quantity)
        BigDecimal(baskets_count.to_s) * BigDecimal(basket_content.basket_quantity(basket_size_id).to_s)
      end
    end
  end
end

module XLSX
  class BasketContent < Base
    include BasketContentsHelper

    def initialize(delivery)
      @delivery = delivery
      @basket_sizes = BasketSize.paid
      @basket_contents =
        @delivery
          .basket_contents
          .includes(:product, :depots, :basketcontents_depots)
          .merge(::BasketContent::Product.order_by_name)

      build_summary_worksheet
      Depot.all.each do |depot|
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
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:quantity)}",
          @basket_contents.map { |bc| bc.basket_quantity(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:price)}",
          @basket_contents.map { |bc|
            display_price bc.unit_price, bc.basket_quantity(basket_size)
          })
      end
      add_column(
        ::BasketContent.human_attribute_name(:surplus),
        @basket_contents.map { |bc| bc.surplus_quantity })
      add_column(
        "#{::BasketContent.human_attribute_name(:surplus)} - #{::BasketContent.human_attribute_name(:price)}",
        @basket_contents.map { |bc| display_price bc.unit_price, bc.surplus_quantity })
      add_column(
        Depot.model_name.human(count: 2),
        @basket_contents.map { |bc| display_depots(bc.depots) })
    end

    def build_depot_worksheet(depot, baskets)
      add_worksheet(depot.name)

      basket_contents = @basket_contents.for_depot(depot)

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
          basket_contents.map { |bc| baskets_count if bc.baskets_count(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:quantity)}",
          basket_contents.map { |bc| bc.basket_quantity(basket_size) })
        add_column(
          "#{basket_size.name} - #{::BasketContent.human_attribute_name(:price)}",
          basket_contents.map { |bc|
            display_price bc.unit_price, bc.basket_quantity(basket_size)
          })
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

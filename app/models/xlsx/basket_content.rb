module XLSX
  class BasketContent < Base
    include ActionView::Helpers::TextHelper
    include BasketContentsHelper

    def initialize(delivery)
      @delivery = delivery
      @basket_contents =
        @delivery
          .basket_contents
          .includes(:vegetable)
          .merge(Vegetable.order_by_name)

      build_recap_worksheet
      Depot.all.each do |d|
        build_depot_worksheet(d)
      end
    end

    def filename
      [
        ::BasketContent.model_name.human(count: 2),
        "##{@delivery.number}",
        @delivery.date.strftime('%Y%m%d')
      ].join('-') + '.xlsx'
    end

    private

    def build_recap_worksheet
      add_worksheet I18n.t('delivery.recap')

      baskets = @delivery.baskets.not_absent
      add_basket_content_columns(@basket_contents, baskets)

      add_column(
        ::BasketContent.human_attribute_name(:surplus),
        @basket_contents.map { |bc| display_surplus_quantity(bc) })
    end

    def build_depot_worksheet(depot)
      add_worksheet(depot.name)

      basket_contents = @basket_contents.for_depot(depot)
      baskets = depot.baskets.not_absent.where(delivery_id: @delivery)
      add_basket_content_columns(basket_contents, baskets)
    end

    def add_basket_content_columns(basket_contents, baskets)
      small_baskets_count = baskets.where(basket_size_id: BasketSize.small).sum(:quantity)
      big_baskets_count = baskets.where(basket_size_id: BasketSize.big).sum(:quantity)

      add_column(
        Vegetable.model_name.human(count: 2),
        basket_contents.map { |bc| bc.vegetable.name })

      add_column(
        ::BasketContent.human_attribute_name(:quantity),
        basket_contents.map { |bc|
          quantity =
            bc.small_basket_quantity * small_baskets_count +
            bc.big_basket_quantity * big_baskets_count
          display_quantity(bc, quantity: quantity)
        })

      add_column(
        BasketSize.small.name,
        basket_contents.map { |bc|
          display_basket_quantity(bc, :small, count: small_baskets_count)
        })
      add_column(
        BasketSize.big.name,
        basket_contents.map { |bc|
          display_basket_quantity(bc, :big, count: big_baskets_count)
        })
    end
  end
end

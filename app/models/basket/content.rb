# frozen_string_literal: true

module Basket::Content
  extend ActiveSupport::Concern

  class_methods do
    def contents_by_id(baskets)
      return {} unless Current.org.basket_content_member_visible?

      visible = baskets.select(&:contents_visible?)
      return {} if visible.empty?

      by_delivery = BasketContent
        .where(delivery_id: visible.map(&:delivery_id).uniq)
        .joins(:product).merge(BasketContent::Product.ordered)
        .includes(:depots, product: :producer)
        .group_by(&:delivery_id)

      visible.each_with_object({}) { |basket, grouped|
        matched = by_delivery.fetch(basket.delivery_id, []).select { |content|
          content_for?(content, basket)
        }
        grouped[basket.id] = matched if matched.any?
      }
    end

    private

    def content_for?(content, basket)
      content.basket_quantity(basket.basket_size).positive? &&
        content.depots.any? { |depot| depot.id == basket.depot_id }
    end
  end

  def contents
    delivery.basket_contents
      .for_depot(depot_id)
      .with_positive_quantity_for(basket_size_id)
      .joins(:product).merge(BasketContent::Product.ordered)
      .includes(product: :producer)
  end

  def contents_visible?
    quantity.to_i.positive? &&
      !absent? &&
      !shifted? &&
      Current.org.basket_content_visible_for_delivery?(delivery)
  end
end

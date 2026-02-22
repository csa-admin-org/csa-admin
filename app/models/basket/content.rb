# frozen_string_literal: true

module Basket::Content
  extend ActiveSupport::Concern

  def contents
    delivery.basket_contents
      .for_depot(depot_id)
      .with_positive_quantity_for(basket_size_id)
      .joins(:product).merge(BasketContent::Product.ordered)
      .includes(:product)
  end
end

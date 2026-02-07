# frozen_string_literal: true

# Provides access to the basket contents (products) for a given basket,
# filtered by the basket's depot and basket size. This logic is shared
# between the member-facing deliveries page and Liquid newsletter drops.
module Basket::Content
  extend ActiveSupport::Concern

  # Returns the basket contents for this basket's delivery, filtered to
  # only include products available at this basket's depot and with a
  # positive quantity for this basket's size, sorted by product name.
  def contents
    delivery.basket_contents
      .for_depot(depot_id)
      .with_positive_quantity_for(basket_size_id)
      .joins(:product).merge(BasketContent::Product.ordered)
      .includes(:product)
  end
end

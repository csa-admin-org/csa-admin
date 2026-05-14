# frozen_string_literal: true

class AddBasketContentDepotPriceRangesToDeliveries < ActiveRecord::Migration[8.0]
  def change
    add_column :deliveries, :basket_content_depot_price_ranges, :json, default: {}
  end
end

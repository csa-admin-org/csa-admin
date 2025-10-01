# frozen_string_literal: true

class AddBasketSizePricePercentageToDeliveries < ActiveRecord::Migration[8.1]
  def change
    add_column :deliveries, :basket_size_price_percentage, :decimal, precision: 8, scale: 2
  end
end

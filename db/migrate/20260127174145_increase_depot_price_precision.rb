# frozen_string_literal: true

class IncreaseDepotPricePrecision < ActiveRecord::Migration[8.1]
  def change
    change_column :depots, :price, :decimal, precision: 8, scale: 3, null: false
    change_column :baskets, :depot_price, :decimal, precision: 8, scale: 3, null: false
  end
end

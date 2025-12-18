# frozen_string_literal: true

class AddDefaultUnitToBasketContentProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :basket_content_products, :default_unit, :string
    add_column :basket_content_products, :default_unit_price, :decimal, precision: 8, scale: 2
  end
end

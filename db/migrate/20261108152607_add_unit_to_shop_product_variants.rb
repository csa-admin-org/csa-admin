# frozen_string_literal: true

class AddUnitToShopProductVariants < ActiveRecord::Migration[8.2]
  def change
    add_column :shop_product_variants, :unit, :string, default: "pc", null: false
    change_column :shop_order_items, :quantity, :decimal, precision: 8, scale: 3, default: 1, null: false
    change_column :shop_product_variants, :stock, :decimal, precision: 8, scale: 3
  end
end

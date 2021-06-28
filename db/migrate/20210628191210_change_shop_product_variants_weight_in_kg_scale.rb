class ChangeShopProductVariantsWeightInKgScale < ActiveRecord::Migration[6.1]
  def change
    change_column :shop_product_variants, :weight_in_kg, :decimal, precision: 8, scale: 3
  end
end

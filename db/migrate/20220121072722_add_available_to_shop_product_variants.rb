class AddAvailableToShopProductVariants < ActiveRecord::Migration[6.1]
  def change
    add_column :shop_product_variants, :available, :boolean, default: true, null: false
    add_index :shop_product_variants, :available
  end
end

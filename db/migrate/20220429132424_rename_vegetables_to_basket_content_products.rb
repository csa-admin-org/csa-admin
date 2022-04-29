class RenameVegetablesToBasketContentProducts < ActiveRecord::Migration[7.0]
  def change
    rename_table :vegetables, :basket_content_products
    rename_column :basket_contents, :vegetable_id, :product_id
  end
end

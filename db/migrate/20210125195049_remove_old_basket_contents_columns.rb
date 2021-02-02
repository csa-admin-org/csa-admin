class RemoveOldBasketContentsColumns < ActiveRecord::Migration[6.1]
  def change
    remove_column :basket_contents, :small_basket_quantity
    remove_column :basket_contents, :big_basket_quantity
    remove_column :basket_contents, :small_baskets_count
    remove_column :basket_contents, :big_baskets_count
    remove_column :basket_contents, :basket_sizes
  end
end

class RenameBasketsToBasketSizes < ActiveRecord::Migration[5.1]
  def change
    rename_table :baskets, :basket_sizes
    rename_column :memberships, :basket_id, :basket_size_id
    rename_column :members, :waiting_basket_id, :waiting_basket_size_id
  end
end

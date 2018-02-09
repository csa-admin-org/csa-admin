class AddQuantityToBasketsBasketComplements < ActiveRecord::Migration[5.2]
  def change
    add_column :baskets, :quantity, :integer, default: 1, null: false
    add_column :baskets_basket_complements, :quantity, :integer, default: 1, null: false
  end
end

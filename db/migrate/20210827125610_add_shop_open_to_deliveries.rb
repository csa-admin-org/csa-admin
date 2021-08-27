class AddShopOpenToDeliveries < ActiveRecord::Migration[6.1]
  def change
    add_column :deliveries, :shop_open, :boolean, default: true
    add_index :deliveries, :shop_open
  end
end

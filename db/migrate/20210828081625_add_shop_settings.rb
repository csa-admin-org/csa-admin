class AddShopSettings < ActiveRecord::Migration[6.1]
  def change
    add_column :acps, :shop_order_maximum_weight_in_kg, :decimal, precision: 8, scale: 3
    add_column :acps, :shop_order_minimal_amount, :decimal, precision: 8, scale: 2
    add_column :acps, :shop_delivery_open_delay_in_days, :integer
    add_column :acps, :shop_delivery_open_last_day_end_time, :time
  end
end

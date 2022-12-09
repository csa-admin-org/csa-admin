class AddShopDeliveriesTable < ActiveRecord::Migration[7.0]
  def change
    create_table :shop_special_deliveries do |t|
      t.date :date, null: false, index: { unique: true }
      t.integer :open_delay_in_days
      t.time :open_last_day_end_time
      t.boolean :open, default: false, null: false
      t.integer :shop_products_count, default: 0, null: false
      t.timestamps
    end

    create_table :shop_products_special_deliveries, id: false do |t|
      t.references :special_delivery, foreign_key: { to_table: :shop_special_deliveries }, null: false, index: true
      t.references :product, foreign_key: { to_table: :shop_products }, null: false, index: false
    end

    add_column :shop_orders, :delivery_type, :string, null: false, default: 'Delivery'
    remove_foreign_key :shop_orders, :deliveries
  end
end

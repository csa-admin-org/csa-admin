class CreateGroupBuyingOrders < ActiveRecord::Migration[6.0]
  def change
    create_table :group_buying_orders do |t|
      t.references :member, null: false, index: true
      t.references :delivery, foreign_key: { to_table: :group_buying_deliveries }, null: false, index: true

      t.integer :items_count, null: false, default: 0
      t.decimal :amount, scale: 2, precision: 8, null: false, default: 0

      t.timestamps
    end

    create_table :group_buying_order_items do |t|
      t.references :order, foreign_key: { to_table: :group_buying_orders }, null: false, index: true
      t.references :product, foreign_key: { to_table: :group_buying_products }, null: false, index: true

      t.integer :quantity, null: false
      t.decimal :price, scale: 2, precision: 8, null: false

      t.timestamps
    end

    add_index :group_buying_order_items, [ :order_id, :product_id ], unique: true
  end
end

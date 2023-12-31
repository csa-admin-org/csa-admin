class CreateShopOrders < ActiveRecord::Migration[6.1]
  def change
    create_table :shop_orders do |t|
      t.references :member, foreign_key: true, null: false, index: false
      t.references :delivery, foreign_key: true, null: false, index: true

      t.string :state, null: false, default: 'cart', index: true
      t.decimal :amount, scale: 2, precision: 8, null: false, default: 0

      t.timestamps
    end
    add_index :shop_orders, [ :member_id, :delivery_id ], unique: true

    create_table :shop_order_items do |t|
      t.references :order, foreign_key: { to_table: :shop_orders }, null: false, index: false
      t.references :product, foreign_key: { to_table: :shop_products }, null: false, index: false
      t.references :product_variant, foreign_key: { to_table: :shop_product_variants }, null: false, index: false

      t.integer :quantity, null: false
      t.decimal :item_price, scale: 2, precision: 8, null: false

      t.timestamps
    end
    add_index :shop_order_items, [ :order_id, :product_id, :product_variant_id ], unique: true, name: 'shop_order_items_unique_index'
  end
end

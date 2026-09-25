# frozen_string_literal: true

class AddShopOrderGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :members, :shop_invoice_period, :string

    create_table :shop_order_groups do |t|
      t.references :member, null: false, foreign_key: true
      t.string :period, null: false
      t.timestamps
    end
    add_index :shop_order_groups, [ :member_id, :period ]

    add_reference :shop_orders, :order_group,
      foreign_key: { to_table: :shop_order_groups }
  end
end

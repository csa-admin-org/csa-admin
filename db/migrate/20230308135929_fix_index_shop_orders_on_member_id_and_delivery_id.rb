class FixIndexShopOrdersOnMemberIdAndDeliveryId < ActiveRecord::Migration[7.0]
  def change
    remove_index :shop_orders, name: 'index_shop_orders_on_member_id_and_delivery_id'
    add_index :shop_orders, [:member_id, :delivery_type, :delivery_id],
      unique: true,
      name: 'index_shop_orders_on_member_and_delivery'
  end
end

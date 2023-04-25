class AddDepotToShopOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :shop_orders, :depot, null: true, foreign_key: true, index: true

    reversible do |dir|
      dir.up do
        Shop::Order.all_without_cart.find_each do |order|
          order.update_column(:depot_id, order.depot&.id)
        end
      end
    end
  end
end

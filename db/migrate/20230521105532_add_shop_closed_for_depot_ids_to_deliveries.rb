class AddShopClosedForDepotIdsToDeliveries < ActiveRecord::Migration[7.0]
  def change
    add_column :deliveries, :shop_closed_for_depot_ids, :integer, array: true, default: []
  end
end

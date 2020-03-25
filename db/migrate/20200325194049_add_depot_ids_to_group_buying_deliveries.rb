class AddDepotIdsToGroupBuyingDeliveries < ActiveRecord::Migration[6.0]
  def change
    add_column :group_buying_deliveries, :depot_ids, :integer, array: true, null: false, default: []
  end
end

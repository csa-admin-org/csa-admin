class AddUnavailableForDepotIdsToShopProducts < ActiveRecord::Migration[6.1]
  def change
    add_column :shop_products, :unavailable_for_depot_ids, :integer, array: true, default: []
  end
end

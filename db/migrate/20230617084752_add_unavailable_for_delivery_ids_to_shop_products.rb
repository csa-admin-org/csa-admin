class AddUnavailableForDeliveryIdsToShopProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :shop_products, :unavailable_for_delivery_ids, :integer, array: true, default: [], null: false
  end
end

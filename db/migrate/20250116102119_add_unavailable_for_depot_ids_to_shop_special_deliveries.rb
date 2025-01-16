# frozen_string_literal: true

class AddUnavailableForDepotIdsToShopSpecialDeliveries < ActiveRecord::Migration[8.0]
  def change
    add_column :shop_special_deliveries, :unavailable_for_depot_ids, :json, default: [], null: false

    add_check_constraint :shop_special_deliveries, "JSON_TYPE(unavailable_for_depot_ids) = 'array'",
      name: "shop_special_deliveries_unavailable_for_depot_ids_is_array"
  end
end

# frozen_string_literal: true

class AddMissingIndexesOnId < ActiveRecord::Migration[8.0]
  def change
    add_index :absences, :session_id
    add_index :activity_participations, :session_id
    add_index :members, :validator_id
    add_index :members, :waiting_delivery_cycle_id
    add_index :members_waiting_alternative_depots, :depot_id
    add_index :members_waiting_alternative_depots, :member_id
    add_index :memberships_basket_complements, :delivery_cycle_id
    add_index :shop_products_special_deliveries, :product_id
  end
end

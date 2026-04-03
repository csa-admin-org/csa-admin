# frozen_string_literal: true

class AddAlternateDepotToMemberships < ActiveRecord::Migration[8.0]
  def change
    add_column :memberships, :alternate_depot_id, :bigint
    add_column :memberships, :alternate_depot_price, :decimal, precision: 8, scale: 3
    add_column :memberships, :alternate_delivery_cycle_id, :bigint

    add_index :memberships, :alternate_depot_id
    add_index :memberships, :alternate_delivery_cycle_id

    add_foreign_key :memberships, :depots, column: :alternate_depot_id
    add_foreign_key :memberships, :delivery_cycles, column: :alternate_delivery_cycle_id
  end
end

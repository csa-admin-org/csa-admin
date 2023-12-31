class DeliveryCyclesRenaming < ActiveRecord::Migration[7.1]
  def change
    rename_table :deliveries_cycles, :delivery_cycles
    rename_table :basket_sizes_deliveries_cycles, :basket_sizes_delivery_cycles
    rename_table :deliveries_cycles_depots, :delivery_cycles_depots

    remove_index :delivery_cycles, :visible
    remove_index :basket_sizes_delivery_cycles, [ :basket_size_id, :deliveries_cycle_id ], unique: true
    remove_index :delivery_cycles_depots, [ :depot_id, :deliveries_cycle_id ], unique: true

    rename_column :acps, :deliveries_cycles_member_order_mode, :delivery_cycles_member_order_mode
    rename_column :basket_sizes_delivery_cycles, :deliveries_cycle_id, :delivery_cycle_id
    rename_column :delivery_cycles_depots, :deliveries_cycle_id, :delivery_cycle_id

    add_index :delivery_cycles, :visible
    add_index :basket_sizes_delivery_cycles, [ :basket_size_id, :delivery_cycle_id ], unique: true
    add_index :delivery_cycles_depots, [ :depot_id, :delivery_cycle_id ], unique: true

    remove_index :memberships, :deliveries_cycle_id
    rename_column :memberships, :deliveries_cycle_id, :delivery_cycle_id
    add_index :memberships, :delivery_cycle_id

    rename_column :members, :waiting_deliveries_cycle_id, :waiting_delivery_cycle_id
    rename_column :newsletter_segments, :deliveries_cycle_ids, :delivery_cycle_ids

    rename_column :memberships_basket_complements, :deliveries_cycle_id, :delivery_cycle_id
  end
end

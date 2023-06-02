class AddMemberOrderModesToAcps < ActiveRecord::Migration[7.0]
  def change
    add_column :acps, :basket_sizes_member_order_mode, :string, null: false, default: 'price_desc'
    add_column :acps, :basket_complements_member_order_mode, :string, null: false, default: 'deliveries_count_desc'
    add_column :acps, :depots_member_order_mode, :string, null: false, default: 'price_asc'
    add_column :acps, :deliveries_cycles_member_order_mode, :string, null: false, default: 'deliveries_count_desc'

    # Replace form_priority with member_order_priority
    add_column :basket_sizes, :member_order_priority, :integer, null: false, default: 1
    add_column :basket_complements, :member_order_priority, :integer, null: false, default: 1
    add_column :depots, :member_order_priority, :integer, null: false, default: 1
    add_column :deliveries_cycles, :member_order_priority, :integer, null: false, default: 1
  end
end

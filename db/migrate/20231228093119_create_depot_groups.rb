class CreateDepotGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :depot_groups do |t|
      t.jsonb :names, default: {}, null: false
      t.jsonb :public_names, default: {}, null: false

      t.integer :member_order_priority, default: 1, null: false

      t.timestamps
    end

    add_reference :depots, :group, foreign_key: { to_table: :depot_groups }, index: true
  end
end

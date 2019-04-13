class CreateDeliveriesDepots < ActiveRecord::Migration[5.2]
  def change
    create_table :deliveries_depots do |t|
      t.references :depot, null: false, index: false
      t.references :delivery, null: false, index: false
    end
    add_index :deliveries_depots, [:depot_id, :delivery_id],
      unique: true, name: 'deliveries_depots_unique_index'

    delivery_ids = Delivery.pluck(:id)
    Depot.find_each do |depot|
      depot.delivery_ids = delivery_ids
      depot.save!(validate: false)
    end
  end
end

class AddDeliveriesCountsCaching < ActiveRecord::Migration[7.0]
  def change
    add_column :deliveries_cycles, :deliveries_counts, :jsonb, default: {}, null: false

    DeliveriesCycle.reset_cache!
  end
end

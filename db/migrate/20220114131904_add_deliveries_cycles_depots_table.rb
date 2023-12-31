class AddDeliveriesCyclesDepotsTable < ActiveRecord::Migration[6.1]
  def change
    create_table :deliveries_cycles_depots do |t|
      t.references :depot, null: false, index: false
      t.references :deliveries_cycle, null: false, index: false
    end
    add_index :deliveries_cycles_depots, [ :depot_id, :deliveries_cycle_id ],
      unique: true, name: 'deliveries_cycles_depots_unique_index'

    cycles = DeliveriesCycle.all
    Depot.find_each do |d|
      c = cycles.detect { |c| c.current_deliveries == d.current_deliveries && c.future_deliveries == d.future_deliveries }
      c ||= cycles.first
      execute <<-SQL
        INSERT
          INTO deliveries_cycles_depots(depot_id,deliveries_cycle_id)
          VALUES (#{d.id}, #{c.id});
      SQL
    end
  end
end

class AddBasketSizesDeliveriesCyclesTable < ActiveRecord::Migration[7.1]
  def change
    create_table :basket_sizes_deliveries_cycles do |t|
      t.references :basket_size, null: false, index: false
      t.references :deliveries_cycle, null: false, index: false
    end
    add_index :basket_sizes_deliveries_cycles, [ :basket_size_id, :deliveries_cycle_id ],
      unique: true, name: 'basket_sizes_deliveries_cycles_unique_index'

    deliveries_cycle_ids = DeliveriesCycle.pluck(:id)
    basket_size_ids = BasketSize.pluck(:id)
    basket_size_ids.each do |basket_size_id|
      deliveries_cycle_ids.each do |deliveries_cycle_id|
        execute <<-SQL
          INSERT
            INTO basket_sizes_deliveries_cycles(basket_size_id,deliveries_cycle_id)
            VALUES (#{basket_size_id}, #{deliveries_cycle_id});
        SQL
      end
    end
  end
end

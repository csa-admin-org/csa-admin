class AddDeliveryCycleToBasketSizes < ActiveRecord::Migration[7.1]
  def change
    add_reference :basket_sizes, :delivery_cycle, foreign_key: true, null: true

    drop_table :basket_sizes_delivery_cycles
  end
end

class AddUniqueIndexOnDeliveriesDate < ActiveRecord::Migration[6.1]
  def change
    remove_index :deliveries, :date
    add_index :deliveries, :date, unique: true
  end
end

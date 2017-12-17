class Deliveries < ActiveRecord::Migration[4.2]
  def change
    create_table :deliveries do |t|
      t.date :date, null: false
      t.timestamps
    end
    add_index :deliveries, :date
  end
end

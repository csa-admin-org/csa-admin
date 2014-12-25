class Deliveries < ActiveRecord::Migration
  def change
    create_table :deliveries do |t|
      t.date :date, null: false
      t.timestamps
    end
    add_index :deliveries, :date
  end
end

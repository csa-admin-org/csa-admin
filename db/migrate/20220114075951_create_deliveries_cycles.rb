class CreateDeliveriesCycles < ActiveRecord::Migration[6.1]
  def change
    create_table :deliveries_cycles do |t|
      t.jsonb :names, default: {}, null: false
      t.jsonb :public_names, default: {}, null: false
      t.integer :form_priority, default: 0, null: false
      t.boolean :visible, default: false, null: false, index: true

      t.integer :wdays, default: Array(0..6), array: true, null: false
      t.integer :months, default: Array(0..12), array: true, null: false

      t.integer :week_numbers, default: 0, null: false
      t.integer :results, default: 0, null: false

      t.timestamps
    end
  end
end

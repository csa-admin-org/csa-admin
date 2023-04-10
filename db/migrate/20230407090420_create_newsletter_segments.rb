class CreateNewsletterSegments < ActiveRecord::Migration[7.0]
  def change
    create_table :newsletter_segments do |t|
      t.jsonb :titles, default: {}, null: false

      t.integer :depot_ids, array: true, default: [], null: false
      t.integer :basket_size_ids, array: true, default: [], null: false
      t.integer :basket_complement_ids, array: true, default: [], null: false
      t.integer :deliveries_cycle_ids, array: true, default: [], null: false
      t.string :renewal_state

      t.timestamps
    end
  end
end

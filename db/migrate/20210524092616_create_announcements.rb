class CreateAnnouncements < ActiveRecord::Migration[6.1]
  def change
    create_table :announcements do |t|
      t.jsonb :texts, default: {}, null: false
      t.integer :delivery_ids, array: true, default: [], null: false
      t.integer :depot_ids, array: true, default: [], null: false

      t.timestamps
    end
  end
end

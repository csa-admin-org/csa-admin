class CreateNewHalfdayTables < ActiveRecord::Migration[5.0]
  def change
    create_table :halfdays do |t|
      t.date :date, null: false, index: true
      t.time :start_time, null: false, index: true
      t.time :end_time, null: false
      t.string :place, null: false
      t.string :place_url
      t.string :activity, null: false
      t.text :description
      t.integer :participants_limit
      t.timestamps
    end

    create_table :halfday_participations do |t|
      t.references :halfday, foreign_key: true, null: false, index: true
      t.references :member, foreign_key: true, null: false, index: true
      t.references :validator, foreign_key: { to_table: :admins }

      t.string :state, null: false, default: 'pending'
      t.datetime :validated_at
      t.datetime :rejected_at

      t.integer :participants_count, null: false, default: 1
      t.string :carpooling_phone

      t.timestamps
    end
  end
end

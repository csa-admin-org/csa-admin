class CreateHalfdayWorks < ActiveRecord::Migration
  def change
    create_table :halfday_works do |t|
      t.references :member, index: true, null: false
      t.date :date, null: false
      t.string :periods, array: true, null: false
      t.datetime :validated_at
      t.references :validator, index: true
      t.integer :participants_count, default: 1, null: false

      t.timestamps
    end

    add_index :halfday_works, :date
    add_index :halfday_works, :validated_at
  end
end

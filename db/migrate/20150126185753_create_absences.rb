class CreateAbsences < ActiveRecord::Migration
  def change
    create_table :absences do |t|
      t.references :member, index: true
      t.date :started_on
      t.date :ended_on
      t.text :note

      t.timestamps
    end
  end
end

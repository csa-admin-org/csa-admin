class CreateVegetables < ActiveRecord::Migration[5.0]
  def change
    create_table :vegetables do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :vegetables, :name, unique: true
  end
end

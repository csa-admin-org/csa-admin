class CreateHalfdayPresets < ActiveRecord::Migration[5.2]
  def change
    create_table :halfday_presets do |t|
      t.string :place, null: false
      t.string :place_url
      t.string :activity, null: false
    end

    add_index :halfday_presets, [:place, :activity], unique: true
  end
end

class CreateGribouilles < ActiveRecord::Migration[4.2]
  def change
    create_table :gribouilles do |t|
      t.references :delivery, index: true, null: false
      t.text :header
      t.text :basket_content
      t.text :fields_echo
      t.text :events
      t.text :footer

      t.datetime :sent_at
      t.timestamps null: false
    end
  end
end

class CreateAcps < ActiveRecord::Migration[5.1]
  def change
    create_table :acps do |t|
      t.string :name, null: false
      t.string :host, null: false
      t.string :tenant_name, null: false

      t.timestamps
    end
    add_index :acps, :host
    add_index :acps, :tenant_name
  end
end

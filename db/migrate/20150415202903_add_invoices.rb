class AddInvoices < ActiveRecord::Migration[4.2]
  def change
    enable_extension :hstore

    create_table :invoices do |t|
      t.references :member, index: true, null: false
      t.date :date, null: false
      t.text :number, null: false
      t.decimal :amount, scale: 2, precision: 8, null: false
      t.decimal :balance, scale: 2, precision: 8, null: false
      t.hstore :data, null: false

      t.timestamps
    end

    add_index :invoices, :number
  end
end

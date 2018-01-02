class CreatePayments < ActiveRecord::Migration[5.1]
  def change
    create_table :payments do |t|
      t.references :member, foreign_key: true, null: false, index: true
      t.references :invoice, foreign_key: true, index: true

      t.decimal :amount, precision: 8, scale: 2, null: false
      t.date :date, null: false

      t.string :isr_data

      t.datetime :deleted_at
      t.timestamps
    end
    add_index :payments, :deleted_at
    add_index :payments, :isr_data, unique: true

    add_column :invoices, :canceled_at, :datetime
    add_column :invoices, :state, :string, default: 'not_sent', null: false
    add_index :invoices, :state
    add_index :invoices, [:date, :member_id], unique: true
  end
end

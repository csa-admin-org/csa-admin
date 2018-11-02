class CreateInvoiceItems < ActiveRecord::Migration[5.2]
  def change
    create_table :invoice_items do |t|
      t.belongs_to :invoice, foreign_key: true, index: true

      t.string :description, null: false
      t.decimal :amount, scale: 2, precision: 8, null: false

      t.timestamps
    end
  end
end

class CreateNewInvoices < ActiveRecord::Migration
  def change
    rename_table :invoices, :old_invoices

    create_table :invoices do |t|
      t.references :member, index: true, null: false
      t.date :date, null: false
      t.decimal :balance, scale: 2, precision: 8
      t.decimal :amount, scale: 2, precision: 8, null: false
      t.decimal :support_amount, scale: 2, precision: 8
      t.string :memberships_amount_description
      t.decimal :memberships_amount, scale: 2, precision: 8
      t.json :memberships_amounts_data
      t.decimal :remaining_memberships_amount, scale: 2, precision: 8
      t.decimal :paid_memberships_amount, scale: 2, precision: 8
      t.json :isr_balance_data
      t.datetime :sent_at
      t.json :overdue_notices

      t.timestamps
    end
  end
end

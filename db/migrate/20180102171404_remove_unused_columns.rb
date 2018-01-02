class RemoveUnusedColumns < ActiveRecord::Migration[5.1]
  def change
    remove_column :invoices, :memberships_amounts_data
    remove_column :invoices, :isr_balance_data
    remove_column :invoices, :isr_balance
    remove_column :invoices, :manual_balance
    remove_column :invoices, :note

    remove_column :memberships, :note
  end
end

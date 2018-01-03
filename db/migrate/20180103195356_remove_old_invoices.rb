class RemoveOldInvoices < ActiveRecord::Migration[5.1]
  def change
    drop_table :old_invoices
  end
end

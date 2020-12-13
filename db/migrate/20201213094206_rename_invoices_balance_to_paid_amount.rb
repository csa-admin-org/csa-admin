class RenameInvoicesBalanceToPaidAmount < ActiveRecord::Migration[6.0]
  def change
    rename_column :invoices, :balance, :paid_amount
  end
end

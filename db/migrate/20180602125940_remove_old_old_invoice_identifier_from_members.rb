class RemoveOldOldInvoiceIdentifierFromMembers < ActiveRecord::Migration[5.2]
  def change
    remove_column :members, :old_old_invoice_identifier
  end
end

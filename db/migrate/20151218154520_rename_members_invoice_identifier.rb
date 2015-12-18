class RenameMembersInvoiceIdentifier < ActiveRecord::Migration
  def change
    rename_column :members, :invoice_identifier, :old_old_invoice_identifier
  end
end

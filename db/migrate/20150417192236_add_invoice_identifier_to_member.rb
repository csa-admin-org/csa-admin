class AddInvoiceIdentifierToMember < ActiveRecord::Migration[4.2]
  def change
    add_column :members, :invoice_identifier, :integer
    add_index :members, :invoice_identifier
  end
end

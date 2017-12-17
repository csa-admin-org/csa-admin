class AddPdfOidToInvoices < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :pdf, :oid
  end
end

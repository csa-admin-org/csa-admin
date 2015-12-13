class AddPdfOidToInvoices < ActiveRecord::Migration
  def change
    add_column :invoices, :pdf, :oid
  end
end

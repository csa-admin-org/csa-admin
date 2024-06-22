# frozen_string_literal: true

class AddPDFOidToInvoices < ActiveRecord::Migration[4.2]
  def change
    add_column :invoices, :pdf, :oid
  end
end

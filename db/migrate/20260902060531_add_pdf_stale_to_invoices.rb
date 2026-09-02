# frozen_string_literal: true

class AddPDFStaleToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :pdf_stale, :boolean, default: false, null: false
  end
end

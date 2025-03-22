# frozen_string_literal: true

class AddInvoiceDocumentNamesToOrganizations < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :invoice_document_names, :json, default: {}, null: false
  end
end

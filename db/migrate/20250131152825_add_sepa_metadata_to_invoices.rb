# frozen_string_literal: true

class AddSepaMetadataToInvoices < ActiveRecord::Migration[8.0]
  def change
    add_column :invoices, :sepa_metadata, :json, default: {}, null: false
  end
end

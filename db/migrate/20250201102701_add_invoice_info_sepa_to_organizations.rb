# frozen_string_literal: true

class AddInvoiceInfoSepaToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :invoice_sepa_infos, :json, default: {}, null: false
  end
end

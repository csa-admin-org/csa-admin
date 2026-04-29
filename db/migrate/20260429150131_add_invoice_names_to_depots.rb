# frozen_string_literal: true

class AddInvoiceNamesToDepots < ActiveRecord::Migration[8.1]
  def change
    add_column :depots, :invoice_names, :json, default: {}, null: false
  end
end

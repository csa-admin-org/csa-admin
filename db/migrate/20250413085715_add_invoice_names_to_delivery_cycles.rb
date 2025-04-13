# frozen_string_literal: true

class AddInvoiceNamesToDeliveryCycles < ActiveRecord::Migration[8.1]
  def change
    add_column :delivery_cycles, :invoice_names, :json, default: {}, null: false
  end
end

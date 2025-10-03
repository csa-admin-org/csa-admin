# frozen_string_literal: true

class AddSEPADirectDebitOrderToInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :invoices, :sepa_direct_debit_order_id, :string
    add_column :invoices, :sepa_direct_debit_order_uploaded_at, :datetime
  end
end

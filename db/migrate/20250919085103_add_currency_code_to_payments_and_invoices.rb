# frozen_string_literal: true

class AddCurrencyCodeToPaymentsAndInvoices < ActiveRecord::Migration[8.1]
  def change
    add_column :payments, :currency_code, :string, limit: 3
    add_column :invoices, :currency_code, :string, limit: 3
  end
end

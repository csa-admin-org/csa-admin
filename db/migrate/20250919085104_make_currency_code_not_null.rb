# frozen_string_literal: true

class MakeCurrencyCodeNotNull < ActiveRecord::Migration[8.1]
  def change
    change_column_null :payments, :currency_code, false
    change_column_null :invoices, :currency_code, false
  end
end

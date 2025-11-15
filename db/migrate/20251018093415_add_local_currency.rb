# frozen_string_literal: true

class AddLocalCurrency < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :local_currency_code, :string, limit: 3
    add_column :organizations, :local_currency_identifier, :string
    add_column :organizations, :local_currency_wallet, :string
    add_column :organizations, :local_currency_secret, :string

    add_column :members, :use_local_currency, :boolean, default: false
    add_index :members, :use_local_currency
  end
end

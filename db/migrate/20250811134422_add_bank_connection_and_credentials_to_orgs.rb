# frozen_string_literal: true

class AddBankConnectionAndCredentialsToOrgs < ActiveRecord::Migration[8.1]
  def change
    add_column :organizations, :bank_connection_type, :string
    add_column :organizations, :bank_credentials, :json, default: {}
  end
end

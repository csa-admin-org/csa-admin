# frozen_string_literal: true

class DropLegacyBankConnectionColumnsFromOrganizations < ActiveRecord::Migration[8.1]
  def change
    remove_column :organizations, :bank_connection_type, :string
    remove_column :organizations, :bank_credentials, :json, default: {}
  end
end

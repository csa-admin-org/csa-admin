# frozen_string_literal: true

class DropLegacyBankConnectionColumnsFromOrganizations < ActiveRecord::Migration[8.1]
  def up
    remove_column :organizations, :bank_connection_type, :string
    remove_column :organizations, :bank_credentials, :json, default: {}
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "legacy organization credentials cannot be reconstructed; restore a database backup instead"
  end
end

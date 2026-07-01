# frozen_string_literal: true

class CreateBankConnections < ActiveRecord::Migration[8.1]
  def up
    create_table :bank_connections do |t|
      t.string :provider, null: false
      t.string :name
      t.boolean :active, null: false, default: false
      t.string :state, null: false, default: "draft"

      t.json :credentials, null: false, default: {}
      t.json :settings, null: false, default: {}
      t.json :capabilities, null: false, default: {}
      t.json :status_details, null: false, default: {}

      t.datetime :last_health_check_at
      t.string :health_status, null: false, default: "unknown"

      t.datetime :last_import_attempted_at
      t.datetime :last_import_succeeded_at
      t.datetime :last_no_data_at

      t.datetime :last_upload_attempted_at
      t.datetime :last_upload_succeeded_at

      t.string :last_error_class
      t.text :last_error_message

      t.timestamps
    end

    add_index :bank_connections, :provider
    add_index :bank_connections, :state
    add_index :bank_connections, :active,
      unique: true,
      where: "active = 1",
      name: "index_bank_connections_on_active_unique"

    add_check_constraint :bank_connections, "JSON_TYPE(credentials) = 'object'",
      name: "bank_connections_credentials_is_object"
    add_check_constraint :bank_connections, "JSON_TYPE(settings) = 'object'",
      name: "bank_connections_settings_is_object"
    add_check_constraint :bank_connections, "JSON_TYPE(capabilities) = 'object'",
      name: "bank_connections_capabilities_is_object"
    add_check_constraint :bank_connections, "JSON_TYPE(status_details) = 'object'",
      name: "bank_connections_status_details_is_object"
  end

  def down
    drop_table :bank_connections
  end
end

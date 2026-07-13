# frozen_string_literal: true

class UseNonContainerSEPADirectDebitUpload < ActiveRecord::Migration[8.1]
  XML_CONTAINER_BTF = {
    "order_type" => "BTU",
    "service_name" => "SDD",
    "scope" => "DE",
    "service_option" => "COR",
    "container" => "XML",
    "message_name" => "pain.008",
    "signature_flag" => true
  }.freeze
  NON_CONTAINER_BTF = {
    "order_type" => "BTU",
    "service_name" => "SDD",
    "service_option" => "COR",
    "message_name" => "pain.008",
    "signature_flag" => true
  }.freeze
  NON_CONTAINER_SERVICE = NON_CONTAINER_BTF.except("order_type", "signature_flag").freeze

  class MigrationBankConnection < ActiveRecord::Base
    self.table_name = "bank_connections"
  end

  def up
    MigrationBankConnection.reset_column_information
    MigrationBankConnection.where(provider: "ebics").find_each do |connection|
      migrate_connection(connection) if eligible?(connection)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
      "restoring XML-container settings would reintroduce invalid raw PAIN uploads"
  end

  private

  def eligible?(connection)
    settings = connection.settings.to_h.deep_stringify_keys
    upload = settings.dig("uploads", "sepa_direct_debit").to_h

    settings["protocol"] == "H005" &&
      upload["mode"] == "btf" &&
      upload["schema"] == "pain.008.001.08" &&
      upload["btf"].to_h.deep_stringify_keys == XML_CONTAINER_BTF &&
      non_container_service_advertised?(connection)
  end

  def non_container_service_advertised?(connection)
    capabilities = connection.capabilities.to_h.deep_stringify_keys
    uploads = capabilities.dig("h005", "htd_btf_uploads")

    Array(uploads).any? do |info|
      info = info.to_h.deep_stringify_keys
      info["admin_order_type"] == "BTU" &&
        info["service"].to_h.deep_stringify_keys == NON_CONTAINER_SERVICE
    end
  end

  def migrate_connection(connection)
    settings = connection.settings.to_h.deep_stringify_keys.deep_dup
    settings.dig("uploads", "sepa_direct_debit")["btf"] = NON_CONTAINER_BTF.deep_dup
    connection.update_columns(settings: settings)
  end
end

# frozen_string_literal: true

require "test_helper"
require Rails.root.join("db/migrate/20260713130000_use_non_container_sepa_direct_debit_upload").to_s

class UseNonContainerSEPADirectDebitUploadTest < ActiveSupport::TestCase
  Connection = UseNonContainerSEPADirectDebitUpload::MigrationBankConnection

  setup do
    Connection.delete_all
  end

  test "rewrites the exact generated XML-container tuple when HTD advertises non-container Core debit" do
    connection = create_connection(
      settings: faulty_settings.merge("operator_note" => "preserve me"),
      capabilities: advertised_non_container_capabilities)

    migrate

    settings = connection.reload.settings
    assert_equal UseNonContainerSEPADirectDebitUpload::NON_CONTAINER_BTF,
      settings.dig("uploads", "sepa_direct_debit", "btf")
    assert_equal "pain.008.001.08", settings.dig("uploads", "sepa_direct_debit", "schema")
    assert_equal "CDD", settings.dig("uploads", "sepa_direct_debit", "order_type")
    assert_equal "preserve me", settings.fetch("operator_note")
  end

  test "does not rewrite without the exact advertised non-container service" do
    missing_capability = create_connection(settings: faulty_settings, capabilities: {})
    container_only = create_connection(
      settings: faulty_settings,
      capabilities: advertised_non_container_capabilities(
        service: UseNonContainerSEPADirectDebitUpload::XML_CONTAINER_BTF.except(
          "order_type",
          "signature_flag")))
    different_option = create_connection(
      settings: faulty_settings,
      capabilities: advertised_non_container_capabilities(
        service: UseNonContainerSEPADirectDebitUpload::NON_CONTAINER_SERVICE.merge(
          "service_option" => "B2B")))

    migrate

    [ missing_capability, container_only, different_option ].each do |connection|
      assert_equal UseNonContainerSEPADirectDebitUpload::XML_CONTAINER_BTF,
        connection.reload.settings.dig("uploads", "sepa_direct_debit", "btf")
    end
  end

  test "does not rewrite modified, versioned, or differently versioned-schema settings" do
    modified = create_connection(
      settings: faulty_settings.tap do |settings|
        settings.dig("uploads", "sepa_direct_debit", "btf")["service_option"] = "B2B"
      end,
      capabilities: advertised_non_container_capabilities)
    versioned = create_connection(
      settings: faulty_settings.tap do |settings|
        settings.dig("uploads", "sepa_direct_debit", "btf")["version"] = "08"
      end,
      capabilities: advertised_non_container_capabilities)
    missing_schema = create_connection(
      settings: faulty_settings.tap do |settings|
        settings.dig("uploads", "sepa_direct_debit").delete("schema")
      end,
      capabilities: advertised_non_container_capabilities)
    different_schema = create_connection(
      settings: faulty_settings.tap do |settings|
        settings.dig("uploads", "sepa_direct_debit")["schema"] = "pain.008.001.02"
      end,
      capabilities: advertised_non_container_capabilities)

    migrate

    assert_equal "B2B", modified.reload.settings.dig("uploads", "sepa_direct_debit", "btf", "service_option")
    assert_equal "08", versioned.reload.settings.dig("uploads", "sepa_direct_debit", "btf", "version")
    assert_nil missing_schema.reload.settings.dig("uploads", "sepa_direct_debit", "schema")
    assert_equal "pain.008.001.02", different_schema.reload.settings.dig("uploads", "sepa_direct_debit", "schema")
    [ missing_schema, different_schema ].each do |connection|
      assert_equal UseNonContainerSEPADirectDebitUpload::XML_CONTAINER_BTF,
        connection.settings.dig("uploads", "sepa_direct_debit", "btf")
    end
  end

  test "leaves existing non-container settings unchanged on repeated runs" do
    settings = faulty_settings
    settings.dig("uploads", "sepa_direct_debit")["btf"] =
      UseNonContainerSEPADirectDebitUpload::NON_CONTAINER_BTF.deep_dup
    connection = create_connection(
      settings: settings,
      capabilities: advertised_non_container_capabilities)

    2.times { migrate }

    assert_equal settings, connection.reload.settings
  end

  private

  def migrate
    UseNonContainerSEPADirectDebitUpload.new.up
  end

  def create_connection(settings:, capabilities:)
    Connection.create!(
      provider: "ebics",
      settings: settings,
      capabilities: capabilities)
  end

  def faulty_settings
    {
      "protocol" => "H005",
      "downloads" => { "preserve" => true },
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "order_type" => "CDD",
          "btf" => UseNonContainerSEPADirectDebitUpload::XML_CONTAINER_BTF.deep_dup
        }
      }
    }
  end

  def advertised_non_container_capabilities(service: UseNonContainerSEPADirectDebitUpload::NON_CONTAINER_SERVICE)
    {
      "h005" => {
        "htd_btf_uploads" => [
          {
            "admin_order_type" => "BTU",
            "num_sig_required" => 1,
            "service" => service
          }
        ]
      }
    }
  end
end

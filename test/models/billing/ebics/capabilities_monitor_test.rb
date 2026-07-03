# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::CapabilitiesMonitorTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
  end

  test "records healthy capabilities when configured BTF services are advertised" do
    error = ErrorRecorder.new
    connection = create_connection

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report,
      error_reporter: error).check!

    connection.reload
    assert_empty error.unexpected_errors
    assert_equal "healthy", connection.health_status
    assert connection.last_health_check_at?
    assert_nil connection.last_error_class
    assert_equal "DE", connection.capabilities.fetch("country_code")
    assert_equal "healthy", connection.status_details.dig("last_capabilities_check", "status")
  end

  test "baselines advertised versions on first check" do
    error = ErrorRecorder.new
    connection = create_connection

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report(payment_service: payment_service.merge("version" => "08")),
      error_reporter: error).check!

    connection.reload
    assert_empty error.unexpected_errors
    assert_equal "healthy", connection.health_status
    assert_nil connection.last_error_class
  end

  test "reports newly advertised versions compared to previous capabilities" do
    error = ErrorRecorder.new
    connection = create_connection
    connection.update!(capabilities: capabilities_report(payment_service: payment_service.merge("version" => "04")))

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report(payment_service: payment_service.merge("version" => "08")),
      error_reporter: error).check!

    connection.reload
    assert_equal "warning", connection.health_status
    assert_equal "UnexpectedEBICSCapability", connection.last_error_class
    assert_equal [ "New EBICS BTF message version advertised" ], connection.status_details.dig("last_capabilities_check", "warnings")
    assert_equal 1, error.unexpected_errors.size
    message, context = error.unexpected_errors.first
    assert_equal "New EBICS BTF message version advertised", message
    assert_equal [ "08" ], context.fetch("advertised_versions")
  end

  test "does not warn when SEPA upload settings are absent" do
    error = ErrorRecorder.new
    connection = create_connection(settings: download_only_settings)

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report,
      error_reporter: error).check!

    connection.reload
    assert_empty error.unexpected_errors
    assert_equal "healthy", connection.health_status
    assert_nil connection.last_error_class
  end

  test "does not warn about legacy upload settings when SEPA is not configured" do
    org(country_code: "CH", features: [], sepa_creditor_identifier: nil)
    error = ErrorRecorder.new
    connection = create_connection(settings: legacy_upload_settings)

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report,
      error_reporter: error).check!

    connection.reload
    assert_empty error.unexpected_errors
    assert_equal "healthy", connection.health_status
    assert_nil connection.last_error_class
  end

  test "reports configured BTF services that disappear from bank capabilities" do
    error = ErrorRecorder.new
    connection = create_connection

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report(upload_service: upload_service.merge("service_option" => "B2B")),
      error_reporter: error).check!

    connection.reload
    assert_equal "warning", connection.health_status
    assert_equal "UnexpectedEBICSCapability", connection.last_error_class
    message, context = error.unexpected_errors.first
    assert_equal "Configured EBICS BTF operation is no longer advertised", message
    assert_equal "sepa_direct_debit_upload", context.fetch("operation_kind")
    assert_equal "BTU", context.dig("operation", "order_type")
  end

  private

  def create_connection(settings: ebics_settings)
    BankConnection.create!(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: settings)
  end

  def ebics_settings
    download_only_settings.merge(
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "btf" => upload_operation
        }
      })
  end

  def download_only_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => payment_operation
        }
      }
    }
  end

  def legacy_upload_settings
    download_only_settings.merge(
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "order_type",
          "order_type" => "CDD"
        }
      })
  end

  def capabilities_report(payment_service: self.payment_service, upload_service: self.upload_service)
    {
      "country_code" => "DE",
      "h005" => {
        "admin_orders" => {
          "HTD" => { "status" => "ok" },
          "HAA" => { "status" => "ok" }
        },
        "htd_btf_downloads" => [ { "admin_order_type" => "BTD", "service" => payment_service } ],
        "htd_btf_uploads" => [ { "admin_order_type" => "BTU", "service" => upload_service } ],
        "haa_available_downloads" => []
      }
    }
  end

  def payment_operation
    Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
  end

  def upload_operation
    Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(scope: "DE", service_option: "COR", container: "XML", version: nil)
  end

  def payment_service
    payment_operation.except("order_type")
  end

  def upload_service
    upload_operation.except("order_type", "signature_flag")
  end

  def ebics_credentials
    {
      keys: "secret-key-json",
      secret: "secret-passphrase",
      url: "https://ebics.example.test",
      host_id: "MULTIVIA",
      participant_id: "PARTNERID",
      client_id: "USERID"
    }
  end
end

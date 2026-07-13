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
    assert_empty error.reports
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
    assert_empty error.reports
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
    warning, context, options = error.reports.first
    assert_instance_of Billing::EBICS::CapabilitiesMonitor::Warning, warning
    assert_equal "New EBICS BTF message version advertised", warning.message
    assert_equal [ "08" ], context.fetch("advertised_versions")
    assert_equal({ handled: false, severity: :error, source: "ebics.capabilities_monitor" }, options)
    assert_equal "background", context.dig(:appsignal, :namespace)
    assert_equal "EBICS capabilities monitor", context.dig(:appsignal, :action)
  end

  test "warns when SEPA upload settings are absent for a SEPA configured organization" do
    error = ErrorRecorder.new
    connection = create_connection(settings: download_only_settings, legacy_persisted: true)

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report,
      error_reporter: error).check!

    connection.reload
    assert_equal "warning", connection.health_status
    assert_equal "UnexpectedEBICSCapability", connection.last_error_class
    assert_includes connection.status_details.dig("last_capabilities_check", "warnings"),
      "Active EBICS connection must use BTF operation settings"
    assert_equal "sepa_direct_debit_upload", error.reports.last.second.fetch("operation_kind")
  end

  test "does not warn about legacy upload settings when SEPA is not configured" do
    org(country_code: "CH", features: [], sepa_creditor_identifier: nil)
    error = ErrorRecorder.new
    connection = create_connection(settings: legacy_upload_settings, legacy_persisted: true)

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report,
      error_reporter: error).check!

    connection.reload
    assert_empty error.reports
    assert_equal "healthy", connection.health_status
    assert_nil connection.last_error_class
  end

  test "does not report configured tuple as missing when admin orders fail" do
    error = ErrorRecorder.new
    connection = create_connection

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report(
        admin_orders: failed_admin_orders,
        htd_btf_downloads: [],
        htd_btf_uploads: [],
        haa_available_downloads: []),
      error_reporter: error).check!

    connection.reload
    assert_equal "warning", connection.health_status
    assert_equal [
      "EBICS capabilities admin-order check failed",
      "EBICS capabilities admin-order check failed"
    ], connection.status_details.dig("last_capabilities_check", "warnings")
    assert_equal [
      "EBICS capabilities admin-order check failed",
      "EBICS capabilities admin-order check failed"
    ], error.reports.map { |warning, _context, _options| warning.message }
    assert_not_includes error.reports.to_json, "provider response text"
    assert_not_includes connection.capabilities.to_json, "provider response text"
  end

  test "ignores explicitly tolerated admin order return codes" do
    error = ErrorRecorder.new
    connection = create_connection(settings: ignored_admin_order_error_settings)

    Billing::EBICS::CapabilitiesMonitor.new(
      connection: connection,
      report: capabilities_report(
        admin_orders: failed_admin_orders,
        htd_btf_downloads: [],
        htd_btf_uploads: [],
        haa_available_downloads: []),
      error_reporter: error).check!

    connection.reload
    assert_empty error.reports
    assert_equal "healthy", connection.health_status
    assert_empty connection.status_details.dig("last_capabilities_check", "warnings")
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
    warning, context, options = error.reports.first
    assert_instance_of Billing::EBICS::CapabilitiesMonitor::Warning, warning
    assert_equal "Configured EBICS BTF operation is no longer advertised", warning.message
    assert_equal "sepa_direct_debit_upload", context.fetch("operation_kind")
    assert_equal "BTU", context.dig("operation", "order_type")
    assert_equal :error, options.fetch(:severity)
  end

  private

  def create_connection(settings: ebics_settings, legacy_persisted: false)
    connection = BankConnection.new(
      provider: "ebics",
      name: "MULTIVIA",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: settings)

    if legacy_persisted
      # Capability monitoring must diagnose legacy persisted configurations without permitting new ones.
      connection.save!(validate: false)
    else
      connection.save!
    end

    connection
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

  def ignored_admin_order_error_settings
    ebics_settings.merge(
      "monitoring" => {
        "capabilities" => {
          "ignored_admin_order_return_codes" => {
            "HTD" => [ "090003" ],
            "HAA" => [ "090003" ]
          }
        }
      })
  end

  def capabilities_report(
    payment_service: self.payment_service,
    upload_service: self.upload_service,
    admin_orders: { "HTD" => { "status" => "ok" }, "HAA" => { "status" => "ok" } },
    htd_btf_downloads: [ { "admin_order_type" => "BTD", "service" => payment_service } ],
    htd_btf_uploads: [ { "admin_order_type" => "BTU", "service" => upload_service } ],
    haa_available_downloads: [])
    {
      "country_code" => "DE",
      "h005" => {
        "admin_orders" => admin_orders,
        "htd_btf_downloads" => htd_btf_downloads,
        "htd_btf_uploads" => htd_btf_uploads,
        "haa_available_downloads" => haa_available_downloads
      }
    }
  end

  def failed_admin_orders
    {
      "HTD" => {
        "status" => "error",
        "class" => "Billing::EBICS::ClientError",
        "message" => "provider response text",
        "return_code" => "090003",
        "report_text" => "provider response text"
      },
      "HAA" => {
        "status" => "error",
        "class" => "Billing::EBICS::ClientError",
        "message" => "provider response text",
        "return_code" => "090003",
        "report_text" => "provider response text"
      }
    }
  end

  def payment_operation
    Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
  end

  def upload_operation
    Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(service_option: "COR", version: nil)
  end

  def payment_service
    payment_operation.except("order_type")
  end

  def upload_service
    upload_operation.except("order_type", "signature_flag")
  end

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(
      host_id: "MULTIVIA",
      user_id: "PARTICIPANTID",
      partner_id: "CLIENTID")
  end
end

# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::ReadinessReportTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
  end

  test "reports sanitized EBICS 3.0 readiness" do
    org(country_code: "CH")
    connection = BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: btf_payment_settings.merge("secret" => "settings-secret"))

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "acme", report.fetch("tenant")
    assert_equal connection.id, report.dig("active_connection", "id")
    assert_equal "ebics.example.test", report.dig("ebics", "endpoint_host")
    assert_equal "HOSTID", report.dig("ebics", "host_id")
    assert_equal "H005", report.dig("ebics", "protocol")
    assert_equal BankConnection::FILTERED, report.dig("active_connection", "settings", "secret")
    assert_equal "btf", report.dig("ebics", "current_payment_operation", "mode")
    assert_equal "BTD", report.dig("ebics", "current_payment_operation", "order_type")
    assert_equal "camt.054", report.dig("ebics", "current_payment_operation", "message_name")
    assert_equal "BTD", report.dig("ebics", "recommended_btf_payment_operation", "order_type")
    assert_equal "camt.054", report.dig("ebics", "recommended_btf_payment_operation", "message_name")
    assert report.dig("ebics", "btf_readiness", "h005_configured")
    assert report.dig("ebics", "btf_readiness", "request_build_ready")
    assert report.dig("ebics", "btf_readiness", "manual_download_ready")
    assert_nil report.dig("ebics", "btf_readiness", "manual_download_blocker")
    assert_includes report.dig("ebics", "live_capabilities_check"), "ebics:capabilities"
    assert_sanitized report
  end

  test "reports camt.054 version 08 for the current download when it is advertised" do
    org(country_code: "CH")
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: btf_payment_settings,
      capabilities: {
        "h005" => {
          "htd_btf_downloads" => [
            {
              "admin_order_type" => "BTD",
              "service" => Billing::EBICS::Btf::Presets.camt054(
                service_name: "REP",
                scope: "CH",
                version: "08").except("order_type")
            }
          ]
        }
      })

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "08", report.dig("ebics", "current_payment_operation", "version")
    assert_equal "04", report.dig("ebics", "recommended_btf_payment_operation", "version")
    assert_equal "04", report.dig("active_connection", "settings", "downloads", "payments", "btf", "version")
  end

  test "reports camt.053 version 08 for the current download when it is advertised" do
    german_org(features: [], sepa_creditor_identifier: nil)
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: german_payment_settings,
      capabilities: camt053_capabilities("08"))

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "08", report.dig("ebics", "current_payment_operation", "version")
    assert_equal "camt.053", report.dig("ebics", "current_payment_operation", "message_name")
    assert_nil report.dig("ebics", "recommended_btf_payment_operation", "version")
    assert_equal "camt.053", report.dig("ebics", "recommended_btf_payment_operation", "message_name")
    assert_not report.dig("active_connection", "settings", "downloads", "payments", "btf").key?("version")
  end

  test "reports non-EBICS tenants without EBICS details" do
    BankConnection.create!(
      provider: "bunq",
      active: true,
      state: "ready",
      credentials: { api_key: "secret" })

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "bunq", report.dig("active_connection", "provider")
    assert_nil report.fetch("ebics")
  end

  private

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(secret: "test-passphrase-value").symbolize_keys
  end

  def camt053_capabilities(*versions)
    btf = Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
    services = versions.map { |version| btf.merge("version" => version).except("order_type") }
    {
      "h005" => {
        "htd_btf_downloads" => services.map { |service|
          { "admin_order_type" => "BTD", "service" => service }
        }
      }
    }
  end

  def german_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE")
        }
      }
    }
  end

  def btf_payment_settings
    {
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
    }
  end

  def assert_sanitized(report)
    output = report.to_json

    assert_not_includes output, ebics_credentials.fetch(:secret)
    assert_not_includes output, ebics_credentials.fetch(:keys).first(80)
    assert_not_includes output, "settings-secret"
  end
end

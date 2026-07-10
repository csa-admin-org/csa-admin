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

  test "reports non-EBICS tenants without EBICS details" do
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123" })

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "bas", report.dig("active_connection", "provider")
    assert_nil report.fetch("ebics")
  end

  private

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(secret: "test-passphrase-value").symbolize_keys
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

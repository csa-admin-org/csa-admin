# frozen_string_literal: true

require "test_helper"
require "epics"
require "tempfile"

class Billing::EBICS::ReadinessReportTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
  end

  test "reports sanitized EBICS readiness without live HEV" do
    org(
      country_code: "CH",
      bank_connection_type: "ebics",
      bank_credentials: ebics_credentials)
    connection = BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: legacy_payment_settings)

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "acme", report.fetch("tenant")
    assert_equal "ebics", report.dig("legacy_connection", "provider")
    assert_equal connection.id, report.dig("active_connection", "id")
    assert_equal "ebics.example.test", report.dig("ebics", "endpoint_host")
    assert_equal "HOSTID", report.dig("ebics", "host_id")
    assert_equal "skipped", report.dig("ebics", "hev", "status")
    assert_equal "order_type", report.dig("ebics", "current_payment_operation", "mode")
    assert_equal "Z54", report.dig("ebics", "current_payment_operation", "order_type")
    assert_equal "BTD", report.dig("ebics", "recommended_btf_payment_operation", "order_type")
    assert_equal "camt.054", report.dig("ebics", "recommended_btf_payment_operation", "message_name")
    assert report.dig("ebics", "btf_readiness", "request_build_ready")
    assert_not report.dig("ebics", "btf_readiness", "live_dry_run_ready")
    assert_includes report.dig("ebics", "btf_readiness", "live_dry_run_blocker"), "LIVE_HEV"
    assert_sanitized report
  end

  test "confirms H005 only when live HEV is explicitly enabled" do
    org(
      country_code: "CH",
      bank_connection_type: "ebics",
      bank_credentials: ebics_credentials)
    BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: legacy_payment_settings)

    report = Billing::EBICS::ReadinessReport.new(
      tenant: "acme",
      live_hev: true,
      legacy_client: FakeLegacyClient.new).to_h

    assert_equal "ok", report.dig("ebics", "hev", "status")
    assert_equal "03.00", report.dig("ebics", "hev", "protocols", "H005")
    assert report.dig("ebics", "btf_readiness", "h005_confirmed")
    assert report.dig("ebics", "btf_readiness", "live_dry_run_ready")
    assert_nil report.dig("ebics", "btf_readiness", "live_dry_run_blocker")
  end

  test "reports non-EBICS tenants without EBICS details" do
    org(bank_connection_type: "bas", bank_credentials: { account_number: "123" })
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123" })

    report = Billing::EBICS::ReadinessReport.new(tenant: "acme").to_h

    assert_equal "bas", report.dig("legacy_connection", "provider")
    assert_nil report.fetch("ebics")
  end

  private

  def ebics_credentials
    @ebics_credentials ||= begin
      client = ::Epics::Client.setup(
        "test-passphrase-value",
        "https://ebics.example.test",
        "HOSTID",
        "USERID",
        "PARTNERID",
        2048)
      client.keys["HOSTID.X002"] = client.x
      client.keys["HOSTID.E002"] = client.e

      Tempfile.create do |file|
        client.save_keys(file.path)
        {
          keys: File.read(file.path),
          secret: "test-passphrase-value",
          url: "https://ebics.example.test",
          host_id: "HOSTID",
          participant_id: "PARTNERID",
          client_id: "USERID"
        }
      end
    end
  end

  def legacy_payment_settings
    {
      "protocol" => "H004",
      "downloads" => {
        "payments" => {
          "mode" => "order_type",
          "order_type" => "Z54"
        }
      }
    }
  end

  def assert_sanitized(report)
    output = report.to_json

    assert_not_includes output, ebics_credentials.fetch(:secret)
    assert_not_includes output, ebics_credentials.fetch(:keys).first(80)
  end

  class FakeLegacyClient
    def client
      self
    end

    def HEV
      {
        "H004" => "02.50",
        "H005" => "03.00"
      }
    end
  end
end

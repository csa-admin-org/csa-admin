# frozen_string_literal: true

require "test_helper"

class BankConnectionTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
  end

  test "has no organization reference" do
    assert_not_includes BankConnection.column_names, "organization_id"
  end

  test "stores provider settings outside credentials" do
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: {
        "protocol" => "H004",
        "downloads" => {
          "payments" => {
            "mode" => "order_type",
            "order_type" => "Z54"
          }
        }
      })

    assert_equal ebics_credentials.stringify_keys, connection.credentials
    assert_equal "H004", connection.settings.dig("protocol")
    assert_equal "Z54", connection.settings.dig("downloads", "payments", "order_type")
    assert_not connection.credentials.key?("downloads")
  end

  test "accepts non-EBICS connections without operation settings" do
    connection = BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123", contract_password: "secret" })

    assert_equal "bas", connection.provider
    assert_empty connection.settings
  end

  test "redacts sensitive credentials recursively" do
    connection = BankConnection.new(
      provider: "bunq",
      credentials: {
        "api_key" => "api-secret",
        "user_id" => 123,
        "nested" => {
          "private_key" => "private-secret",
          "public_value" => "visible"
        }
      })

    assert_equal({
      "api_key" => BankConnection::FILTERED,
      "user_id" => 123,
      "nested" => {
        "private_key" => BankConnection::FILTERED,
        "public_value" => "visible"
      }
    }, connection.redacted_credentials)
  end

  test "returns credential keys without values" do
    connection = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials)

    assert_equal %w[client_id host_id keys participant_id secret url], connection.credential_keys
  end

  test "safe summary contains redacted credentials and status metadata" do
    connection = BankConnection.new(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      health_status: "unknown",
      credentials: ebics_credentials,
      settings: { "protocol" => "H004" },
      capabilities: {
        "protocols" => %w[H004 H005],
        "access_token" => "secret-token"
      },
      status_details: {
        "last_check" => "ok",
        "client_secret" => "secret"
      })

    summary = connection.safe_summary

    assert_equal "ebics", summary["provider"]
    assert_equal "HOSTID", summary["name"]
    assert_equal BankConnection::FILTERED, summary.dig("credentials", "secret")
    assert_equal BankConnection::FILTERED, summary.dig("credentials", "keys")
    assert_equal "https://ebics.example.test", summary.dig("credentials", "url")
    assert_equal %w[client_id host_id keys participant_id secret url], summary["credential_keys"]
    assert_equal({ "protocol" => "H004" }, summary["settings"])
    assert_equal BankConnection::FILTERED, summary.dig("capabilities", "access_token")
    assert_equal BankConnection::FILTERED, summary.dig("status_details", "client_secret")
  end

  test "tracks import and upload health status" do
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: { "protocol" => "H005" })
    operation = Billing::EBICS::Operation.btf(
      Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE"))

    connection.mark_import_attempted!(operation: operation)
    connection.mark_import_succeeded!(operation: operation, files_count: 2)
    connection.mark_upload_attempted!(operation: operation, invoice_id: 123)
    connection.mark_upload_succeeded!(operation: operation, invoice_id: 123, order_id: "N0DD")

    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_health_check_at?
    assert connection.last_import_attempted_at?
    assert connection.last_import_succeeded_at?
    assert connection.last_upload_attempted_at?
    assert connection.last_upload_succeeded_at?
    assert_nil connection.last_error_class
    assert_equal 2, connection.status_details.dig("last_import", "files_count")
    assert_equal "btf", connection.status_details.dig("last_import", "operation", "mode")
    assert_equal 123, connection.status_details.dig("last_upload", "invoice_id")
    assert_equal "N0DD", connection.status_details.dig("last_upload", "order_id")
  end

  test "tracks no data and errors" do
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: { "protocol" => "H005" })
    operation = Billing::EBICS::Operation.btf(
      Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE"))

    connection.mark_no_data!(operation: operation)
    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_no_data_at?
    assert_nil connection.last_error_class

    connection.mark_error!(RuntimeError.new("boom"), operation: operation, operation_kind: "payment_download")
    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "RuntimeError", connection.last_error_class
    assert_equal "boom", connection.last_error_message
    assert_equal "payment_download", connection.status_details.dig("last_error", "operation_kind")
  end

  test "tracks capabilities health and warnings" do
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: { "protocol" => "H005" })

    connection.mark_capabilities_checked!(
      report: {
        "country_code" => "DE",
        "h005" => {
          "htd_btf_downloads" => [ { "service" => { "message_name" => "camt.053" } } ]
        }
      },
      status: "warning",
      warnings: [ "New EBICS BTF message version advertised" ])

    connection.reload
    assert_equal "warning", connection.health_status
    assert connection.last_health_check_at?
    assert_equal "DE", connection.capabilities.fetch("country_code")
    assert_equal "UnexpectedEBICSCapability", connection.last_error_class
    assert_equal "New EBICS BTF message version advertised", connection.last_error_message
    assert_equal [ "New EBICS BTF message version advertised" ], connection.status_details.dig("last_capabilities_check", "warnings")
  end

  test "returns EBICS key summary from encrypted credentials" do
    connection = BankConnection.new(
      provider: "ebics",
      credentials: synthetic_ebics_credentials)

    summary = connection.ebics_key_summary

    assert_equal %w[A006 E002 HOSTID.E002 HOSTID.X002 X002], summary.fetch("key_names")
    assert_operator summary.fetch("participant_key_min_bits"), :>=, 2048
    assert_operator summary.fetch("bank_key_min_bits"), :>=, 2048
  end

  test "returns empty EBICS key summary when credentials are incomplete" do
    connection = BankConnection.new(provider: "ebics", credentials: {})

    assert_empty connection.ebics_key_summary
  end

  test "returns redacted EBICS key inspection errors" do
    connection = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials.merge(keys: "invalid-key-data"))

    summary = connection.ebics_key_summary

    assert_equal "Unable to inspect EBICS keys", summary.dig("error", "message")
  end

  test "instantiates provider adapter" do
    connection = BankConnection.new(
      provider: "mock",
      credentials: { password: "secret" })

    assert_instance_of Billing::EBICSMock, connection.adapter
  end

  test "passes EBICS BTF settings to provider adapter" do
    connection = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: {
        "downloads" => {
          "payments" => {
            "mode" => "btf",
            "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
          }
        }
      })

    operation = connection.adapter.operation_config.payment_download
    assert_equal "BTD", operation.order_type
    assert_equal "camt.054", operation.btf.fetch("message_name")
  end

  test "keeps active scope separate from lifecycle state" do
    connection = BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })

    assert connection.active?
    assert connection.ready?
    assert_equal [ connection ], BankConnection.active
    assert_equal [ connection ], BankConnection.ready
  end

  test "allows only one active connection" do
    BankConnection.create!(
      provider: "mock",
      active: true,
      state: "ready",
      credentials: { password: "secret" })

    connection = BankConnection.new(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123" })

    assert_not connection.valid?
    assert_includes connection.errors[:active], "is already used by another bank connection"
  end

  private

  def ebics_credentials
    {
      url: "https://ebics.example.test",
      secret: "secret",
      host_id: "HOSTID",
      participant_id: "PARTICIPANTID",
      client_id: "CLIENTID",
      keys: "keys"
    }
  end
end

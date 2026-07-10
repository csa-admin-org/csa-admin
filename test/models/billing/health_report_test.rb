# frozen_string_literal: true

require "test_helper"

class Billing::HealthReportTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(name: "Ferme Acme", country_code: "CH")
  end

  test "table includes active EBICS connection health and key strength" do
    travel_to Time.zone.local(2026, 7, 5, 10, 30) do
      connection = create_ebics_connection(keysize: 4096)
      connection.mark_import_succeeded!(operation: { "mode" => "btf", "kind" => "payment_import" })

      table = Billing::HealthReport.new(tenant_names: [ "acme" ], now: Time.current).table.to_s

      assert_includes table, "Billing health — 2026-07-05 10:30"
      assert_includes table, "acme"
      assert_not_includes table, "Org"
      assert_not_includes table, "Ferme Acme"
      assert_includes table, "ebics / RAIFCHEC"
      assert_includes table, "🟢 healthy"
      assert_includes table, "ok 2026-07-05"
      assert_not_includes table, "ok 2026-07-05 10:30"
      assert_includes table, "EBICS H005"
      assert_includes table, "4096"
      assert_not_includes table, "4096-bit"
      assert_not_includes table, "rotated"
    end
  end

  test "rotation failure note keeps the active key strength trace" do
    create_ebics_connection(keysize: 2048, rotation_state: "rotation_failed")

    table = Billing::HealthReport.new(tenant_names: [ "acme" ]).table.to_s

    assert_includes table, "2048"
    assert_includes table, "HCS failed; kept 2048"
    assert_not_includes table, "rotation_failed"
  end

  test "provider filter matches bank name and hides non-matching connections" do
    create_connection(provider: "bas", name: "BAS")

    assert_empty Billing::HealthReport.new(tenant_names: [ "acme" ], provider: "ebics").rows

    rows = Billing::HealthReport.new(tenant_names: [ "acme" ], provider: "BAS").rows

    assert_equal 1, rows.size
    assert_equal "bas / BAS", rows.first.fetch(:bank)
  end

  test "reports missing active connection when unfiltered" do
    row = Billing::HealthReport.new(tenant_names: [ "acme" ]).rows.first

    assert_equal "acme", row.fetch(:tenant)
    assert_equal "🔴 missing", row.fetch(:health)
    assert_equal "No active bank connection", row.fetch(:notes)
  end

  private

  def create_ebics_connection(keysize: 2048, rotation_state: keysize >= 4096 ? "rotated" : "candidate")
    create_connection(
      provider: "ebics",
      name: "RAIFCHEC",
      credentials: synthetic_ebics_credentials(secret: secret, keysize: keysize, host_id: "RAIFCHEC"),
      settings: {
        "protocol" => "H005",
        "downloads" => {
          "payments" => {
            "mode" => "btf",
            "btf" => Billing::EBICS::Btf::Presets.camt054(
              service_name: "REP",
              scope: "CH",
              version: "04")
          }
        }
      },
      status_details: {
        "key_rotation" => {
          "state" => rotation_state
        }
      })
  end

  def create_connection(provider:, name:, credentials: credentials_for(provider), settings: {}, status_details: {})
    BankConnection.create!(
      provider: provider,
      name: name,
      active: true,
      state: "ready",
      credentials: credentials,
      settings: settings,
      status_details: status_details)
  end

  def credentials_for(provider)
    case provider
    when "bunq"
      {
        private_key: OpenSSL::PKey::RSA.new(2048).to_pem,
        installation_token: "test_installation_token",
        api_key: "test_api_key",
        user_id: 12345,
        monetary_account_id: 67890
      }
    else
      { account_number: "123", contract_password: "secret", password: "secret" }
    end
  end

  def secret
    "test-passphrase-value"
  end
end

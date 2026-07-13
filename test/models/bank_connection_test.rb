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
      active: false,
      state: "draft",
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
        },
        "pending_key_rotation" => {
          "keys" => "pending-key-secret",
          "public_digest" => "visible-digest"
        }
      })

    assert_equal({
      "api_key" => BankConnection::FILTERED,
      "user_id" => 123,
      "nested" => {
        "private_key" => BankConnection::FILTERED,
        "public_value" => "visible"
      },
      "pending_key_rotation" => {
        "keys" => BankConnection::FILTERED,
        "public_digest" => "visible-digest"
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
      settings: h005_settings)
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
      settings: h005_settings)
    operation = Billing::EBICS::Operation.btf(
      Billing::EBICS::Btf::Presets.camt053(service_name: "EOP", scope: "DE"))

    connection.mark_no_data!(operation: operation)
    connection.reload
    assert_equal "healthy", connection.health_status
    assert connection.last_no_data_at?
    assert_nil connection.last_error_class

    provider_text = "secret member@example.test <Document>payment data</Document>"
    connection.mark_error!(RuntimeError.new(provider_text), operation: operation, operation_kind: "payment_download")
    connection.reload
    assert_equal "errored", connection.health_status
    assert_equal "RuntimeError", connection.last_error_class
    assert_equal "Payment download failed", connection.last_error_message
    assert_equal "payment_download", connection.status_details.dig("last_error", "operation_kind")
    assert_not_includes connection.attributes.to_json, provider_text
  end

  test "tracks capabilities health and warnings" do
    connection = BankConnection.create!(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings)

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
      credentials: ebics_credentials.merge("keys" => "invalid-key-data"))

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

  test "reports SEPA direct debit upload capability" do
    ebics = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: sepa_direct_debit_upload_settings,
      capabilities: sepa_direct_debit_upload_capabilities)
    unadvertised_upload = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: sepa_direct_debit_upload_settings)
    mismatched_version = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: sepa_direct_debit_upload_settings,
      capabilities: sepa_direct_debit_upload_capabilities(version: "08"))
    matching_version = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: sepa_direct_debit_upload_settings(version: "08"),
      capabilities: sepa_direct_debit_upload_capabilities(version: "08"))
    missing_upload_settings = BankConnection.new(provider: "ebics", credentials: ebics_credentials)
    legacy_upload_settings = BankConnection.new(
      provider: "ebics",
      credentials: ebics_credentials,
      settings: {
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "order_type",
            "order_type" => "CDD"
          }
        }
      })
    bas = BankConnection.new(provider: "bas", credentials: { account_number: "123", contract_password: "secret" })
    bunq = BankConnection.new(provider: "bunq", credentials: { api_key: "secret" })
    mock = BankConnection.new(provider: "mock", credentials: { password: "secret" })

    assert ebics.sepa_direct_debit_upload?
    assert_not unadvertised_upload.sepa_direct_debit_upload?
    assert_not mismatched_version.sepa_direct_debit_upload?
    assert matching_version.sepa_direct_debit_upload?
    assert_not missing_upload_settings.sepa_direct_debit_upload?
    assert_not legacy_upload_settings.sepa_direct_debit_upload?
    assert_not bas.sepa_direct_debit_upload?
    assert_not bunq.sepa_direct_debit_upload?
    assert mock.sepa_direct_debit_upload?
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

  test "rejects active connections that are not ready" do
    connection = BankConnection.new(
      provider: "mock",
      active: true,
      state: "draft",
      credentials: { password: "secret" })

    assert_not_predicate connection, :valid?
    assert_includes connection.errors[:state], "must be ready when active"
  end

  test "validates active EBICS protocol credentials and BTF settings" do
    partial_onboarding = BankConnection.new(
      provider: "ebics",
      active: false,
      state: "initializing",
      credentials: {},
      settings: {})
    assert_predicate partial_onboarding, :valid?

    invalid_protocol = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.merge("protocol" => "H004"))
    assert_not_predicate invalid_protocol, :valid?
    assert_includes invalid_protocol.errors[:settings], "must use EBICS protocol H005 when active"

    missing_credentials = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials.except("secret"),
      settings: h005_settings)
    assert_not_predicate missing_credentials, :valid?
    assert_includes missing_credentials.errors[:credentials], "is missing required EBICS values: secret"

    incomplete_btd = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge("downloads" => { "payments" => { "btf" => { "container" => nil } } }))
    assert_not_predicate incomplete_btd, :valid?
    assert_includes incomplete_btd.errors[:settings], "must include a complete BTD payment download configuration"

    inconsistent_btu = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "schema" => "pain.008.001.02",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload
          }
        }))
    assert_not_predicate inconsistent_btu, :valid?
    assert_includes inconsistent_btu.errors[:settings], "must use a PAIN.008 schema matching the configured BTU version"
  end

  test "ignores disabled legacy upload placeholders for organizations without SEPA" do
    org(sepa_creditor_identifier: nil)
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "order_type",
            "order_type" => "CDD"
          }
        }))

    assert_predicate connection, :valid?
  end

  test "rejects legacy upload placeholders when the organization uses SEPA" do
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "order_type",
            "order_type" => "CDD"
          }
        }))

    assert_not_predicate connection, :valid?
    assert_includes connection.errors[:settings], "must include a complete BTU SEPA direct debit upload configuration"
  end

  test "rejects XML-container settings for raw SEPA direct debit uploads" do
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "schema" => "pain.008.001.08",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
              scope: "DE",
              container: "XML",
              version: nil)
          }
        }))

    assert_not_predicate connection, :valid?
    assert_includes connection.errors[:settings], "must use a non-container BTU service for SEPA direct debit uploads"
    assert_not connection.sepa_direct_debit_upload?
  end

  test "accepts the versionless non-container MULTIVIA BTU tuple with an explicit supported schema" do
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "schema" => "pain.008.001.08",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
              service_option: "COR",
              version: nil)
          }
        }))

    assert_predicate connection, :valid?
  end

  test "rejects a versionless BTU tuple without an explicit supported schema" do
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials,
      settings: h005_settings.deep_merge(
        "uploads" => {
          "sepa_direct_debit" => {
            "mode" => "btf",
            "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(
              service_option: "COR",
              version: nil)
          }
        }))

    assert_not_predicate connection, :valid?
    assert_includes connection.errors[:settings], "must use an explicit supported PAIN.008 schema without a BTU version"
  end

  test "rejects active EBICS connections with unreadable key material" do
    connection = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: ebics_credentials.merge("keys" => "invalid-key-material"),
      settings: h005_settings)

    assert_not_predicate connection, :valid?
    assert_includes connection.errors[:credentials], "must contain valid EBICS key material"
  end

  test "requires active EBICS connections to hold private participant and public configured bank keys" do
    key_material = synthetic_ebics_key_material
    missing_bank_key = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(key_material: key_material.except("HOSTID.E002")),
      settings: h005_settings)
    private_bank_key = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(key_material: key_material.merge("HOSTID.X002" => OpenSSL::PKey::RSA.generate(2048))),
      settings: h005_settings)
    participant_key = OpenSSL::PKey::RSA.generate(2048)
    public_participant_key = BankConnection.new(
      provider: "ebics",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(key_material: key_material.merge("A006" => OpenSSL::PKey::RSA.new(participant_key.public_to_pem))),
      settings: h005_settings)

    assert_not_predicate missing_bank_key, :valid?
    assert_includes missing_bank_key.errors[:credentials], "must contain bank public keys X002 and E002 for the configured host"
    assert_not_predicate private_bank_key, :valid?
    assert_includes private_bank_key.errors[:credentials], "must contain public bank keys X002 and E002"
    assert_not_predicate public_participant_key, :valid?
    assert_includes public_participant_key.errors[:credentials], "must contain private participant keys A006, X002, and E002"
  end

  test "database prevents activating a connection that is not ready" do
    connection = BankConnection.create!(
      provider: "mock",
      active: false,
      state: "draft",
      credentials: { password: "secret" })

    assert_raises ActiveRecord::StatementInvalid do
      connection.update_columns(active: true)
    end
  end

  test "database prevents multiple in-progress EBICS onboarding rows" do
    BankConnection.create!(
      provider: "ebics",
      active: false,
      state: "initializing",
      credentials: {})
    connection = BankConnection.new(
      provider: "ebics",
      active: false,
      state: "waiting_for_bank",
      credentials: {})

    assert_raises ActiveRecord::RecordNotUnique do
      connection.save!(validate: false)
    end
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

  def h005_settings
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

  def sepa_direct_debit_upload_settings(version: nil)
    {
      "uploads" => {
        "sepa_direct_debit" => {
          "mode" => "btf",
          "schema" => "pain.008.001.08",
          "btf" => Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(version: version)
        }
      }
    }
  end

  def sepa_direct_debit_upload_capabilities(version: nil)
    {
      "h005" => {
        "htd_btf_uploads" => [
          {
            "admin_order_type" => "BTU",
            "service" => Billing::EBICS::Btf::Presets
              .sepa_direct_debit_upload(version: version)
              .except("order_type", "signature_flag")
          }
        ]
      }
    }
  end

  def ebics_credentials
    @ebics_credentials ||= synthetic_ebics_credentials(
      user_id: "PARTICIPANTID",
      partner_id: "CLIENTID")
  end
end

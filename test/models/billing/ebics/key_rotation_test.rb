# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::KeyRotationTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "reports unknown for 2048-bit H005 credentials without advertised HCS" do
    connection = create_ebics_connection

    report = key_rotation(connection).readiness

    assert_equal "unknown", report.fetch("state")
    assert_equal 4096, report.fetch("target_bits")
    assert report.fetch("h005_configured")
    assert_empty report.fetch("blockers")
    assert_equal "unknown", report.dig("rotation_strategy", "status")
    assert_equal 2048, report.dig("active_keys", "participant_min_bits")
    assert_equal "participant", report.dig("active_keys", "participant", "A006", "role")
    assert_sanitized report, connection
  end

  test "reports candidate when HCS is advertised" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)

    report = key_rotation(connection).readiness

    assert_equal "candidate", report.fetch("state")
    assert_equal "advertised", report.dig("rotation_strategy", "status")
    assert_equal "HCS", report.dig("rotation_strategy", "order_type")
    assert_includes report.fetch("advertised_key_management"), "HCS"
  end

  test "reports already at target for 4096-bit participant keys" do
    connection = create_ebics_connection(keysize: 4096, capabilities: hcs_capabilities)

    report = key_rotation(connection).readiness

    assert_equal "already_at_target", report.fetch("state")
    assert_empty report.fetch("blockers")
    assert_operator report.dig("active_keys", "participant_min_bits"), :>=, 4096
  end

  test "reports explicit bank-limited 2048-bit state" do
    connection = create_ebics_connection(settings: h005_settings.merge(
      "key_rotation" => {
        "bank_limited_2048" => true,
        "notes" => "Bank confirmed 2048-bit subscriber keys only"
      }))

    report = key_rotation(connection).readiness

    assert_equal "bank_limited_2048", report.fetch("state")
    assert_equal "bank_limited_2048", report.dig("rotation_strategy", "status")
  end

  test "blocks non-H005 credentials" do
    connection = create_ebics_connection(settings: h005_settings.merge("protocol" => "H004"))

    report = key_rotation(connection).readiness

    assert_equal "blocked", report.fetch("state")
    assert_includes report.fetch("blockers"), "Active EBICS connection must use protocol H005"
  end

  test "prepares encrypted pending 4096-bit participant keys without changing active keys" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    active_keys = connection.credentials.to_h.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)

    report = key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys
    pending = credentials.fetch("pending_key_rotation")
    pending_store = Billing::EBICS::KeyStore.new(credentials.merge("keys" => pending.fetch("keys")))
    active_store = Billing::EBICS::KeyStore.new(credentials.merge("keys" => active_keys))

    assert report.fetch("prepared")
    assert_equal active_keys, credentials.fetch("keys")
    assert_not_equal active_keys, pending.fetch("keys")
    assert_equal "prepared", pending.fetch("state")
    assert_equal 4096, pending.fetch("target_bits")
    assert_equal 4096, pending_store.a.bits
    assert_equal 4096, pending_store.x.bits
    assert_equal 4096, pending_store.e.bits
    assert_equal active_store.bank_x.public_digest, pending_store.bank_x.public_digest
    assert_equal active_store.bank_e.public_digest, pending_store.bank_e.public_digest
    assert_equal "pending_rotation", connection.status_details.dig("key_rotation", "state")
    assert_sanitized report, connection
  end

  test "preparation is a no-op when active participant keys already use 4096 bits" do
    connection = create_ebics_connection(keysize: 4096)
    credentials_before = connection.credentials.to_h.deep_stringify_keys

    report = key_rotation(connection).prepare_pending!
    connection.reload

    assert_not report.fetch("prepared")
    assert_equal "already_at_target", report.fetch("state")
    assert_equal credentials_before, connection.credentials.to_h.deep_stringify_keys
  end

  test "builds sanitized HCS request metadata without printing EBICS XML or secrets" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!

    validation = key_rotation(connection.reload).request_build_validation

    assert_equal "ok", validation.fetch("status")
    assert_empty validation.fetch("blockers")
    assert_equal "HCS", validation.dig("safe_metadata", "request", "order_type")
    assert_equal "HCSRequestOrderData", validation.dig("safe_metadata", "request", "order_data", "root")
    assert_equal "ebicsRequest", validation.dig("safe_metadata", "request", "initialisation_request", "root")
    assert_sanitized validation, connection
    assert_not_includes validation.to_json, "<ebicsRequest"
    assert_not_includes validation.to_json, "<HCSRequestOrderData"
  end

  test "submit verify and promote keep active keys untouched until verification" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    active_keys = connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    client = FakeBtfClient.new

    rotation = key_rotation(connection, key_generator: -> { generated_key }, btf_client: client)
    rotation.prepare_pending!
    submit = key_rotation(connection.reload, btf_client: client).submit_pending!
    verify = key_rotation(connection.reload, btf_client: client).verify_pending!
    connection.reload

    assert submit.fetch("submitted")
    assert verify.fetch("verified")
    assert_equal active_keys, connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    assert_equal "verified", connection.credentials.dig("pending_key_rotation", "state")
    assert_equal [ "HCS" ], client.key_change_order_types
    assert_equal [ "HTD" ], client.admin_order_types

    promote = key_rotation(connection.reload, btf_client: client).promote_pending!
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert promote.fetch("promoted")
    assert_nil credentials["pending_key_rotation"]
    assert_not_equal active_keys, credentials.fetch("keys")
    assert_equal active_keys, credentials.dig("previous_key_rotation", "keys")
    assert_equal "rotated", connection.status_details.dig("key_rotation", "state")
    assert_equal "rotated", key_rotation(connection.reload).readiness.fetch("state")
    assert_equal 4096, Billing::EBICS::KeyStore.new(credentials).key_summary.fetch("participant_key_min_bits")
  end

  test "perform reloads persisted state between submit verify and promote" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    active_keys = connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    client = FakeBtfClient.new
    key_rotation(connection, key_generator: -> { generated_key }, btf_client: client).prepare_pending!

    rotation = key_rotation(connection.reload, btf_client: client)
    assert_equal "ok", rotation.request_build_validation.fetch("status")
    result = rotation.perform!
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert result.fetch("promoted")
    assert_equal "rotated", result.fetch("state")
    assert_nil credentials["pending_key_rotation"]
    assert_equal active_keys, credentials.dig("previous_key_rotation", "keys")
    assert_equal [ "HCS" ], client.key_change_order_types
    assert_equal [ "HTD" ], client.admin_order_types
  end

  test "promotion requires verified pending keys" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload).promote_pending!
    end

    assert_includes error.message, "verified before promotion"
  end

  test "submit records uncertain HCS state before live failures and sanitizes persisted failure" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: FailingKeyChangeClient.new("raw bank secret leaked by adapter")).submit_pending!
    end
    connection.reload
    pending = connection.credentials.dig("pending_key_rotation")
    status = connection.status_details.dig("key_rotation")

    assert_includes error.message, "EBICS key rotation failed during submit"
    assert_not_includes error.message, "raw bank secret"
    assert_equal "submitting", pending.fetch("state")
    assert pending.fetch("submit_started_at").present?
    assert_equal "rotation_failed", status.fetch("state")
    assert_equal "submit", status.fetch("stage")
    assert_equal "RuntimeError", status.fetch("error_class")
    assert_equal "EBICS key rotation failed during submit", status.fetch("error_message")
    assert_not_includes status.to_json, "raw bank secret"
  end

  test "submit refuses to retry an uncertain HCS outcome" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!
    assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: FailingKeyChangeClient.new("connection lost after HCS")).submit_pending!
    end

    client = FakeBtfClient.new
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: client).submit_pending!
    end

    assert_includes error.message, "uncertain outcome"
    assert_empty client.key_change_order_types
  end

  test "verify can recover an uncertain submitted HCS without retrying HCS" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!
    assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: FailingKeyChangeClient.new("connection lost after HCS")).submit_pending!
    end

    client = FakeBtfClient.new
    verify = key_rotation(connection.reload, btf_client: client).verify_pending!
    connection.reload

    assert verify.fetch("verified")
    assert_empty client.key_change_order_types
    assert_equal [ "HTD" ], client.admin_order_types
    assert_equal "verified", connection.credentials.dig("pending_key_rotation", "state")
  end

  test "rollback rotates back to previous encrypted keys and preserves replaced keys" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    original_keys = connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    client = FakeBtfClient.new

    rotation = key_rotation(connection, key_generator: -> { generated_key }, btf_client: client)
    rotation.prepare_pending!
    key_rotation(connection.reload, btf_client: client).submit_pending!
    key_rotation(connection.reload, btf_client: client).verify_pending!
    key_rotation(connection.reload, btf_client: client).promote_pending!
    promoted_keys = connection.reload.credentials.to_h.deep_stringify_keys.fetch("keys")

    rollback = key_rotation(connection.reload, btf_client: client).rollback!
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert rollback.fetch("rolled_back")
    assert_equal original_keys, credentials.fetch("keys")
    assert_equal promoted_keys, credentials.dig("previous_key_rotation", "keys")
    assert_equal "candidate", connection.status_details.dig("key_rotation", "state")
    assert_equal "candidate", key_rotation(connection.reload).readiness.fetch("state")
    assert_equal %w[HCS HCS], client.key_change_order_types
    assert_equal %w[HTD HTD], client.admin_order_types
  end

  test "recover rollback promotes previous keys without submitting HCS again" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    original_keys = connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    setup_client = FakeBtfClient.new
    rotation = key_rotation(connection, key_generator: -> { generated_key }, btf_client: setup_client)
    rotation.prepare_pending!
    key_rotation(connection.reload, btf_client: setup_client).submit_pending!
    key_rotation(connection.reload, btf_client: setup_client).verify_pending!
    key_rotation(connection.reload, btf_client: setup_client).promote_pending!
    promoted_keys = connection.reload.credentials.to_h.deep_stringify_keys.fetch("keys")

    recovery_client = FakeBtfClient.new
    recovery = key_rotation(connection.reload, btf_client: recovery_client).recover_rollback!(rollback_result: { "transaction_id" => "TXROLLBACK" })
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert recovery.fetch("rolled_back")
    assert_equal original_keys, credentials.fetch("keys")
    assert_equal promoted_keys, credentials.dig("previous_key_rotation", "keys")
    assert_empty recovery_client.key_change_order_types
    assert_equal [ "HTD" ], recovery_client.admin_order_types
  end

  test "rollback records uncertain state before live HCS failures and sanitizes persisted failure" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    setup_client = FakeBtfClient.new
    rotation = key_rotation(connection, key_generator: -> { generated_key }, btf_client: setup_client)
    rotation.prepare_pending!
    key_rotation(connection.reload, btf_client: setup_client).submit_pending!
    key_rotation(connection.reload, btf_client: setup_client).verify_pending!
    key_rotation(connection.reload, btf_client: setup_client).promote_pending!

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: InspectingRollbackFailureClient.new(connection)).rollback!
    end
    connection.reload
    status = connection.status_details.dig("key_rotation")
    previous = connection.credentials.dig("previous_key_rotation")

    assert_includes error.message, "EBICS key rotation failed during rollback"
    assert_not_includes error.message, "raw rollback secret"
    assert_equal "rollback_submitting", previous.fetch("state")
    assert previous.fetch("rollback_started_at").present?
    assert_equal "rotation_failed", status.fetch("state")
    assert_equal "rollback", status.fetch("stage")
    assert_equal "RuntimeError", status.fetch("error_class")
    assert_equal "EBICS key rotation failed during rollback", status.fetch("error_message")
    assert_not_includes status.to_json, "raw rollback secret"

    client = FakeBtfClient.new
    retry_error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: client).rollback!
    end

    assert_includes retry_error.message, "uncertain outcome"
    assert_empty client.key_change_order_types
  end

  private

  def create_ebics_connection(keysize: 2048, settings: h005_settings, capabilities: {})
    BankConnection.create!(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(secret: secret, keysize: keysize, key_material: key_material(keysize)),
      settings: settings,
      capabilities: capabilities)
  end

  def key_material(keysize)
    return if keysize == 2048

    participant_key = OpenSSL::PKey::RSA.generate(keysize)
    bank_x = OpenSSL::PKey::RSA.generate(2048)
    bank_e = OpenSSL::PKey::RSA.generate(2048)

    {
      "A006" => participant_key,
      "X002" => participant_key,
      "E002" => participant_key,
      "HOSTID.X002" => OpenSSL::PKey::RSA.new(bank_x.public_to_pem),
      "HOSTID.E002" => OpenSSL::PKey::RSA.new(bank_e.public_to_pem)
    }
  end

  def key_rotation(connection, btf_client: nil, **options)
    options[:btf_client_factory] = ->(_credentials, **_client_options) { btf_client } if btf_client
    Billing::EBICS::KeyRotation.new(tenant: "acme", connection: connection, **options)
  end

  def h005_settings
    {
      "protocol" => "H005"
    }
  end

  def hcs_capabilities
    {
      "h005" => {
        "admin_orders" => {
          "HTD" => {
            "status" => "ok",
            "order_infos" => [
              { "admin_order_type" => "HCS" },
              { "admin_order_type" => "HCA" }
            ],
            "legacy_order_types" => %w[INI HIA HPB PUB]
          }
        }
      }
    }
  end

  def secret
    "test-passphrase-value"
  end

  def assert_sanitized(value, connection)
    output = value.to_json
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert_not_includes output, secret
    assert_not_includes output, credentials.fetch("keys").first(80)
    assert_not_includes output, "PRIVATE KEY"
  end

  class FakeBtfClient
    attr_reader :key_change_order_types, :admin_order_types

    def initialize
      @key_change_order_types = []
      @admin_order_types = []
    end

    def key_change_order_data_xml(target_key_store:, order_type:)
      "<HCSRequestOrderData/>"
    end

    def key_change_request_xml(target_key_store:, order_type:)
      "<ebicsRequest/>"
    end

    def key_change(target_key_store:, order_type:)
      key_change_order_types << order_type
      raise "Expected 4096-bit target participant keys" unless target_key_store.key_summary.fetch("participant_key_min_bits") == 4096 || key_change_order_types.size == 2

      Billing::EBICS::BtfClient::KeyChangeResult.new(transaction_id: "TX123", order_id: "N0DD")
    end

    def admin_order(order_type)
      admin_order_types << order_type
      Billing::EBICS::BtfClient::AdminOrderResult.new(order_data: "<HTDResponseOrderData/>", receipt_sent: false)
    end
  end

  class FailingKeyChangeClient
    def initialize(message)
      @message = message
    end

    def key_change(target_key_store:, order_type:)
      raise @message
    end
  end

  class InspectingRollbackFailureClient
    def initialize(connection)
      @connection = connection
    end

    def key_change(target_key_store:, order_type:)
      status = @connection.reload.status_details.fetch("key_rotation")

      raise "rollback status was not persisted before live HCS" unless status.fetch("state") == "rollback_submitting"
      raise "rollback start timestamp was not persisted before live HCS" unless status.fetch("rollback_started_at").present?

      raise "raw rollback secret leaked by adapter"
    end
  end
end

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
    connection = create_ebics_connection(
      settings: h005_settings.merge("protocol" => "H004"),
      legacy_persisted: true)

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
    assert_equal "uncertain", pending.fetch("state")
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

  test "claims HCS before the live request and stops a competing caller" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!

    competing_client = FakeBtfClient.new
    client = FakeBtfClient.new(on_key_change: -> {
      error = assert_raises(Billing::EBICS::UnsupportedOperation) do
        key_rotation(connection.reload, btf_client: competing_client).submit_pending!
      end
      assert_includes error.message, "uncertain outcome"
    })

    report = key_rotation(connection.reload, btf_client: client).submit_pending!

    assert report.fetch("submitted")
    assert_equal [ "HCS" ], client.key_change_order_types
    assert_empty competing_client.key_change_order_types
    assert_nil connection.reload.credentials.dig("pending_key_rotation", "submit_claim_token")
  end

  test "claims pending verification and stops a competing caller" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!
    key_rotation(connection.reload, btf_client: FakeBtfClient.new).submit_pending!

    competing_client = FakeBtfClient.new
    client = FakeBtfClient.new(on_admin_order: ->(_order_type) {
      report = key_rotation(connection.reload, btf_client: competing_client).verify_pending!
      assert_not report.fetch("verified")
      assert_empty competing_client.admin_order_types
    })

    report = key_rotation(connection.reload, btf_client: client).verify_pending!

    assert report.fetch("verified")
    assert_equal [ "HTD" ], client.admin_order_types
    assert_nil connection.reload.credentials.dig("pending_key_rotation", "verify_claim_token")
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

  test "does not discard a pending rotation after HCS starts with an uncertain outcome" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!
    assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload, btf_client: FailingKeyChangeClient.new("connection lost after HCS")).submit_pending!
    end

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      key_rotation(connection.reload).discard_pending!
    end

    assert_includes error.message, "submission has started"
    assert connection.reload.credentials.dig("pending_key_rotation", "keys").present?
  end

  test "discard pending keeps active keys and removes pending rotation" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    active_keys = connection.credentials.to_h.deep_stringify_keys.fetch("keys")
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    key_rotation(connection, key_generator: -> { generated_key }).prepare_pending!

    report = key_rotation(connection.reload).discard_pending!(reason: "bank_rejected_hcs")
    connection.reload
    credentials = connection.credentials.to_h.deep_stringify_keys
    status = connection.status_details.dig("key_rotation")

    assert report.fetch("discarded")
    assert_equal active_keys, credentials.fetch("keys")
    assert_nil credentials["pending_key_rotation"]
    assert_equal "rotation_failed", status.fetch("state")
    assert_equal "discard_pending", status.fetch("stage")
    assert_equal "bank_rejected_hcs", status.fetch("reason")
    assert_equal "rotation_failed", report.fetch("state")
    assert_sanitized report, connection
  end

  test "discard pending is a no-op when there is no pending rotation" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    credentials_before = connection.credentials.to_h.deep_stringify_keys

    report = key_rotation(connection).discard_pending!(reason: "already_absent")
    connection.reload

    assert_not report.fetch("discarded")
    assert_equal "No pending key rotation to discard", report.fetch("message")
    assert_equal credentials_before, connection.credentials.to_h.deep_stringify_keys
  end

  test "purges retained previous keys after verified rotation" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    generated_key = OpenSSL::PKey::RSA.generate(4096)
    client = FakeBtfClient.new
    rotation = key_rotation(connection, key_generator: -> { generated_key }, btf_client: client)
    rotation.prepare_pending!
    key_rotation(connection.reload, btf_client: client).submit_pending!
    key_rotation(connection.reload, btf_client: client).verify_pending!
    key_rotation(connection.reload, btf_client: client).promote_pending!
    assert connection.reload.credentials.dig("previous_key_rotation", "keys").present?

    report = key_rotation(connection.reload).purge_previous!(reason: "verified_after_rotation")
    connection.reload

    assert report.fetch("purged")
    assert_nil connection.credentials.dig("previous_key_rotation")
    assert_nil report["previous_rotation"]
    assert_equal "verified_after_rotation", connection.status_details.dig("key_rotation", "previous_keys_purge_reason")
    assert connection.status_details.dig("key_rotation", "previous_keys_purged_at").present?
  end

  test "purge previous is a no-op when no previous keys are retained" do
    connection = create_ebics_connection(capabilities: hcs_capabilities)
    credentials_before = connection.credentials.to_h.deep_stringify_keys

    report = key_rotation(connection).purge_previous!(reason: "already_absent")
    connection.reload

    assert_not report.fetch("purged")
    assert_equal "No previous key rotation to purge", report.fetch("message")
    assert_equal credentials_before, connection.credentials.to_h.deep_stringify_keys
  end

  private

  def create_ebics_connection(keysize: 2048, settings: h005_settings, capabilities: {}, legacy_persisted: false)
    connection = BankConnection.new(
      provider: "ebics",
      name: "HOSTID",
      active: true,
      state: "ready",
      credentials: synthetic_ebics_credentials(secret: secret, keysize: keysize, key_material: key_material(keysize)),
      settings: settings,
      capabilities: capabilities)

    if legacy_persisted
      # Key rotation must report an existing non-H005 row without allowing new ones.
      connection.save!(validate: false)
    else
      connection.save!
    end

    connection
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
      "protocol" => "H005",
      "downloads" => {
        "payments" => {
          "mode" => "btf",
          "btf" => Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")
        }
      }
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

    def initialize(on_key_change: nil, on_admin_order: nil)
      @on_key_change = on_key_change
      @on_admin_order = on_admin_order
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
      raise "Expected 4096-bit target participant keys" unless target_key_store.key_summary.fetch("participant_key_min_bits") == 4096

      @on_key_change&.call
      Billing::EBICS::BtfClient::KeyChangeResult.new(transaction_id: "TX123", order_id: "N0DD")
    end

    def admin_order(order_type)
      admin_order_types << order_type
      @on_admin_order&.call(order_type)
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
end

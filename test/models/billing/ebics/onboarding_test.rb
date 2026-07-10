# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"

class Billing::EBICS::OnboardingTest < ActiveSupport::TestCase
  setup do
    BankConnection.delete_all
    org(country_code: "CH")
  end

  test "initializes inactive H005 connection with encrypted participant keys" do
    report = onboarding.initialize_connection!(
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "Test Bank",
      target_bits: 2048)
    connection = BankConnection.last
    credentials = connection.credentials.to_h.deep_stringify_keys
    key_store = Billing::EBICS::KeyStore.new(credentials)

    assert report.fetch("initialized")
    assert_equal "initializing", connection.state
    assert_not connection.active?
    assert_equal "H005", connection.settings.fetch("protocol")
    assert_equal "CLIENTID", credentials.fetch("client_id")
    assert_equal "PARTICIPANTID", credentials.fetch("participant_id")
    assert_equal "CLIENTID", key_store.partner_id
    assert_equal "PARTICIPANTID", key_store.user_id
    assert_equal "initialized", connection.status_details.dig("onboarding", "state")
    assert_equal 2048, key_store.a.bits
    assert_equal %w[A006 E002 X002], key_store.keys.keys.sort
    assert_sanitized report, connection
  end

  test "initializing an existing bank connection forces it inactive" do
    connection = BankConnection.create!(
      provider: "ebics",
      name: "Existing EBICS setup",
      active: true,
      state: "draft",
      health_status: "unknown",
      credentials: { "temporary" => true })

    onboarding(connection).initialize_connection!(
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "Test Bank",
      target_bits: 2048)

    assert_not connection.reload.active?
  end

  test "validates required initialization attributes" do
    assert_initialize_connection_error "EBICS onboarding url is required", url: ""
    assert_initialize_connection_error "EBICS onboarding host_id is required", host_id: ""
    assert_initialize_connection_error "EBICS onboarding client_id is required", client_id: ""
    assert_initialize_connection_error "EBICS onboarding participant_id is required", participant_id: ""
  end

  test "validates initialization URL format" do
    assert_initialize_connection_error "EBICS onboarding url must be a valid HTTPS URL", url: "ebics.example.test"
    assert_initialize_connection_error "EBICS onboarding url must be a valid HTTPS URL", url: "http://ebics.example.test"
    assert_initialize_connection_error "EBICS onboarding url must be a valid HTTPS URL", url: "https://user:secret@ebics.example.test"
    assert_initialize_connection_error "EBICS onboarding url must be a valid HTTPS URL", url: "https://"
  end

  test "checks EBICS version before creating the setup connection" do
    probe = FakeVersionProbe.new do
      assert_empty BankConnection.all
    end

    onboarding(version_probe: probe).initialize_connection!(**valid_initialize_connection_attributes)

    assert_equal [ { url: "https://ebics.example.test", host_id: "HOSTID" } ], probe.checks
    assert_equal 1, BankConnection.count
  end

  test "version probe failures do not create a setup connection" do
    [
      Billing::EBICS::VersionProbe::EndpointError,
      Billing::EBICS::VersionProbe::HostIDError,
      Billing::EBICS::VersionProbe::UnsupportedVersionError
    ].each do |error_class|
      BankConnection.delete_all
      error = assert_raises(error_class) do
        onboarding(version_probe: FakeVersionProbe.new(error: error_class.new("preflight failed"))).initialize_connection!(**valid_initialize_connection_attributes)
      end

      assert_equal "preflight failed", error.message
      assert_empty BankConnection.all
    end
  end

  test "submits INI and HIA before waiting for bank activation" do
    connection = initialized_connection
    client = FakeSetupClient.new

    setup = onboarding(connection, btf_client: client)
    ini = setup.submit_ini!
    hia = setup.submit_hia!
    connection.reload

    assert ini.fetch("submitted")
    assert hia.fetch("submitted")
    assert_equal %w[INI HIA], client.submitted_orders
    assert_equal "waiting_for_bank", connection.state
    assert_equal "waiting_for_bank", connection.status_details.dig("onboarding", "state")
    assert connection.status_details.dig("onboarding", "ini_submitted_at").present?
    assert connection.status_details.dig("onboarding", "hia_submitted_at").present?
    assert_sanitized hia, connection
  end

  test "initialization letter is available only after setup orders while waiting for bank" do
    connection = initialized_connection
    client = FakeSetupClient.new

    assert_not onboarding(connection).letter_available?

    onboarding(connection, btf_client: client).submit_ini!
    assert_not onboarding(connection.reload).letter_available?

    onboarding(connection.reload, btf_client: client).submit_hia!
    assert onboarding(connection.reload).letter_available?

    connection.update!(state: "initializing")
    assert_not onboarding(connection.reload).letter_available?
  end

  test "finalizes by storing HPB bank keys and verifying HTD" do
    connection = initialized_connection
    client = FakeSetupClient.new(host_id: "HOSTID")
    onboarding(connection, btf_client: client).submit_ini!
    onboarding(connection.reload, btf_client: client).submit_hia!

    report = onboarding(connection.reload, btf_client: client).finalize!
    connection.reload
    key_store = Billing::EBICS::KeyStore.new(connection.credentials)

    assert report.fetch("finalized")
    assert connection.active?
    assert_equal "ready", connection.state
    assert_equal "healthy", connection.health_status
    assert_equal %w[HTD], client.admin_orders
    assert_equal %w[A006 E002 HOSTID.E002 HOSTID.X002 X002], key_store.keys.keys.sort
    assert_equal "finalized", connection.status_details.dig("onboarding", "state")
    assert_equal "healthy", connection.status_details.dig("last_capabilities_check", "status")
    assert connection.status_details.dig("last_capabilities_check", "checked_at").present?
    assert_sanitized report, connection
  end

  test "finalization reports capability-check failures without undoing setup" do
    connection = initialized_connection
    client = FakeSetupClient.new(host_id: "HOSTID")
    error = ErrorRecorder.new
    onboarding(connection, btf_client: client).submit_ini!
    onboarding(connection.reload, btf_client: client).submit_hia!

    report = onboarding(
      connection.reload,
      btf_client: client,
      error_reporter: error,
      capabilities_monitor_factory: failing_capabilities_monitor_factory).finalize!
    connection.reload

    assert report.fetch("finalized")
    assert connection.active?
    assert_equal "ready", connection.state
    assert_equal "errored", connection.health_status
    assert_equal "RuntimeError", connection.last_error_class
    reported_error, context, = error.reports.sole
    assert_instance_of RuntimeError, reported_error
    assert_equal "capabilities_after_finalization", context.fetch("stage")
    assert_sanitized context, connection
  end

  test "finalize is a no-op once onboarding is finalized" do
    connection = initialized_connection
    client = FakeSetupClient.new(host_id: "HOSTID")
    onboarding(connection, btf_client: client).submit_ini!
    onboarding(connection.reload, btf_client: client).submit_hia!
    onboarding(connection.reload, btf_client: client).finalize!
    second_client = FakeSetupClient.new(host_id: "HOSTID")

    report = onboarding(connection.reload, btf_client: second_client).finalize!

    assert_not report.fetch("finalized")
    assert_equal "EBICS onboarding already finalized", report.fetch("message")
    assert_empty second_client.admin_orders
  end

  test "check finalization activates eligible waiting setup" do
    connection = initialized_connection
    client = FakeSetupClient.new(host_id: "HOSTID")
    onboarding(connection, btf_client: client).submit_ini!
    onboarding(connection.reload, btf_client: client).submit_hia!

    report = onboarding(connection.reload, btf_client: client).check_finalization!
    connection.reload

    assert report.fetch("checked")
    assert report.fetch("finalized")
    assert connection.active?
    assert_equal "ready", connection.state
    assert_equal "healthy", connection.health_status
    assert_equal "finalized", connection.status_details.dig("onboarding", "state")
    assert_equal "finalized", connection.status_details.dig("onboarding", "last_finalization_status")
    assert connection.status_details.dig("onboarding", "last_finalization_check_at").present?
    assert_sanitized report, connection
  end

  test "check finalization keeps waiting setup non-destructive when bank is not ready" do
    connection = initialized_connection
    client = BankNotReadyClient.new(host_id: "HOSTID")
    onboarding(connection, btf_client: FakeSetupClient.new(host_id: "HOSTID")).submit_ini!
    onboarding(connection.reload, btf_client: FakeSetupClient.new(host_id: "HOSTID")).submit_hia!

    report = onboarding(connection.reload, btf_client: client).check_finalization!
    connection.reload

    assert report.fetch("checked")
    assert_not report.fetch("finalized")
    assert_not connection.active?
    assert_equal "waiting_for_bank", connection.state
    assert_equal "unknown", connection.health_status
    assert_equal "waiting_for_bank", connection.status_details.dig("onboarding", "state")
    assert_equal "not_ready", connection.status_details.dig("onboarding", "last_finalization_status")
    assert_equal "091005", connection.status_details.dig("onboarding", "finalization_return_code")
    assert_sanitized report, connection
  end

  test "check finalization reports unexpected errors without marking setup errored" do
    connection = initialized_connection
    error = ErrorRecorder.new
    onboarding(connection, btf_client: FakeSetupClient.new(host_id: "HOSTID")).submit_ini!
    onboarding(connection.reload, btf_client: FakeSetupClient.new(host_id: "HOSTID")).submit_hia!

    report = onboarding(connection.reload, btf_client: BrokenSetupClient.new, error_reporter: error).check_finalization!
    connection.reload

    assert report.fetch("checked")
    assert_not report.fetch("finalized")
    assert_equal "waiting_for_bank", connection.state
    assert_equal "error", connection.status_details.dig("onboarding", "last_finalization_status")
    reported_error, context, = error.reports.sole
    assert_instance_of RuntimeError, reported_error
    assert_equal "check_finalization", context.fetch("stage")
    assert_sanitized context, connection
  end

  test "refuses HIA before INI" do
    connection = initialized_connection

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      onboarding(connection).submit_hia!
    end

    assert_includes error.message, "INI must be submitted before HIA"
  end

  private

  def onboarding(
    connection = nil,
    btf_client: nil,
    error_reporter: Rails.error,
    version_probe: FakeVersionProbe.new,
    capabilities_report_factory: default_capabilities_report_factory,
    capabilities_monitor_factory: default_capabilities_monitor_factory)
    options = {
      now: Time.zone.parse("2026-07-05 10:00"),
      error_reporter: error_reporter,
      key_generator: ->(_bits) { OpenSSL::PKey::RSA.generate(2048) },
      version_probe_factory: -> { version_probe },
      capabilities_report_factory: capabilities_report_factory,
      capabilities_monitor_factory: capabilities_monitor_factory
    }
    options[:btf_client_factory] = ->(_credentials, **_options) { btf_client } if btf_client

    Billing::EBICS::Onboarding.new(connection: connection, **options)
  end

  def default_capabilities_report_factory
    ->(_tenant, _connection) {
      Struct.new(:to_h).new({
        "country_code" => "CH",
        "h005" => {
          "admin_orders" => {
            "HTD" => {
              "status" => "ok"
            }
          }
        }
      })
    }
  end

  def default_capabilities_monitor_factory
    ->(connection, report) {
      Object.new.tap do |monitor|
        monitor.define_singleton_method(:check!) do
          connection.mark_capabilities_checked!(report: report, status: "healthy", warnings: [])
        end
      end
    }
  end

  def failing_capabilities_monitor_factory
    ->(connection, _report) {
      Object.new.tap do |monitor|
        monitor.define_singleton_method(:check!) do
          error = RuntimeError.new("capabilities check failed")
          connection.mark_error!(error, operation_kind: "capabilities_check")
          raise error
        end
      end
    }
  end

  def assert_initialize_connection_error(message, attributes)
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      onboarding.initialize_connection!(**valid_initialize_connection_attributes.merge(attributes))
    end

    assert_equal message, error.message
  end

  def valid_initialize_connection_attributes
    {
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "Test Bank",
      target_bits: 2048
    }
  end

  def initialized_connection
    onboarding.initialize_connection!(
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      client_id: "CLIENTID",
      participant_id: "PARTICIPANTID",
      name: "Test Bank",
      target_bits: 2048)
    BankConnection.last
  end

  def assert_sanitized(value, connection)
    output = value.to_json
    credentials = connection.credentials.to_h.deep_stringify_keys

    assert_not_includes output, credentials.fetch("secret")
    assert_not_includes output, credentials.fetch("keys").first(80)
    assert_not_includes output, "PRIVATE KEY"
  end

  class FakeResponse
    def return_code = "091005"
    def report_text = "EBICS_SUBSCRIBER_UNKNOWN"
  end

  class FakeVersionProbe
    attr_reader :checks

    def initialize(error: nil, &on_check)
      @error = error
      @on_check = on_check
      @checks = []
    end

    def check!(url:, host_id:)
      @on_check&.call
      checks << { url: url, host_id: host_id }
      raise @error if @error
    end
  end

  class FakeSetupClient
    attr_reader :submitted_orders, :admin_orders

    def initialize(host_id: "HOSTID")
      @host_id = host_id
      @submitted_orders = []
      @admin_orders = []
      @bank_x = OpenSSL::PKey::RSA.generate(2048)
      @bank_e = OpenSSL::PKey::RSA.generate(2048)
    end

    def submit_initialization_order(order_type)
      submitted_orders << order_type
      Billing::EBICS::BtfClient::SetupOrderResult.new(
        order_type: order_type,
        transaction_id: "TX-#{order_type}",
        order_id: "ORDER-#{order_type}")
    end

    def fetch_bank_public_keys
      keys = Billing::EBICS::Btf::BankPublicKeys.new(
        host_id: @host_id,
        order_data: hpb_order_data)
      Billing::EBICS::BtfClient::BankPublicKeysResult.new(
        keys: keys,
        order_data: hpb_order_data,
        receipt_sent: true)
    end

    def admin_order(order_type)
      admin_orders << order_type
      Billing::EBICS::BtfClient::AdminOrderResult.new(
        order_data: "<HTDResponseOrderData/>",
        receipt_sent: false)
    end

    private

    def hpb_order_data
      <<~XML
        <HPBResponseOrderData xmlns="urn:org:ebics:H005" xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
          <AuthenticationPubKeyInfo>
            #{rsa_key_value(@bank_x)}
            <AuthenticationVersion>X002</AuthenticationVersion>
          </AuthenticationPubKeyInfo>
          <EncryptionPubKeyInfo>
            #{rsa_key_value(@bank_e)}
            <EncryptionVersion>E002</EncryptionVersion>
          </EncryptionPubKeyInfo>
        </HPBResponseOrderData>
      XML
    end

    def rsa_key_value(key)
      <<~XML
        <PubKeyValue>
          <ds:RSAKeyValue>
            <ds:Modulus>#{crypto_binary(key.n)}</ds:Modulus>
            <ds:Exponent>#{crypto_binary(key.e)}</ds:Exponent>
          </ds:RSAKeyValue>
        </PubKeyValue>
      XML
    end

    def crypto_binary(value)
      hex = value.to_i.to_s(16)
      hex = "0#{hex}" if hex.length.odd?
      Base64.strict_encode64([ hex ].pack("H*"))
    end
  end

  class BankNotReadyClient < FakeSetupClient
    def fetch_bank_public_keys
      response_error = Billing::EBICS::BtfClient::ResponseError.new(FakeResponse.new)
      raise Billing::EBICS::TechnicalError.new(response_error)
    end
  end

  class BrokenSetupClient < FakeSetupClient
    def fetch_bank_public_keys
      raise RuntimeError, "internal setup bug"
    end
  end
end

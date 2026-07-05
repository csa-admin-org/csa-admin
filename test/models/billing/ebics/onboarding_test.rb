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
      partner_id: "PARTNERID",
      user_id: "USERID",
      name: "Test Bank",
      target_bits: 2048)
    connection = BankConnection.last
    credentials = connection.credentials.to_h.deep_stringify_keys
    key_store = Billing::EBICS::KeyStore.new(credentials)

    assert report.fetch("initialized")
    assert_equal "initializing", connection.state
    assert_not connection.active?
    assert_equal "H005", connection.settings.fetch("protocol")
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
      partner_id: "PARTNERID",
      user_id: "USERID",
      name: "Test Bank",
      target_bits: 2048)

    assert_not connection.reload.active?
  end

  test "submits INI and HIA before waiting for bank activation" do
    connection = initialized_connection
    client = FakeSetupClient.new

    ini = onboarding(connection, btf_client: client).submit_ini!
    hia = onboarding(connection.reload, btf_client: client).submit_hia!
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

  test "finalizes by storing HPB bank keys and verifying HTD" do
    connection = initialized_connection
    client = FakeSetupClient.new(host_id: "HOSTID")
    onboarding(connection, btf_client: client).submit_ini!
    onboarding(connection.reload, btf_client: client).submit_hia!

    report = onboarding(connection.reload, btf_client: client).finalize!
    connection.reload
    key_store = Billing::EBICS::KeyStore.new(connection.credentials)

    assert report.fetch("finalized")
    assert_equal "ready", connection.state
    assert_equal "healthy", connection.health_status
    assert_equal %w[HTD], client.admin_orders
    assert_equal %w[A006 E002 HOSTID.E002 HOSTID.X002 X002], key_store.keys.keys.sort
    assert_equal "finalized", connection.status_details.dig("onboarding", "state")
    assert_sanitized report, connection
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

  test "refuses HIA before INI" do
    connection = initialized_connection

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      onboarding(connection).submit_hia!
    end

    assert_includes error.message, "INI must be submitted before HIA"
  end

  private

  def onboarding(connection = nil, btf_client: nil)
    options = {
      now: Time.zone.parse("2026-07-05 10:00"),
      key_generator: ->(_bits) { OpenSSL::PKey::RSA.generate(2048) }
    }
    options[:btf_client_factory] = ->(_credentials, **_options) { btf_client } if btf_client

    Billing::EBICS::Onboarding.new(tenant: "acme", connection: connection, **options)
  end

  def initialized_connection
    onboarding.initialize_connection!(
      url: "https://ebics.example.test",
      host_id: "HOSTID",
      partner_id: "PARTNERID",
      user_id: "USERID",
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
end

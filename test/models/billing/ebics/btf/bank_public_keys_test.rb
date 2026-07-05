# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"

class Billing::EBICS::Btf::BankPublicKeysTest < ActiveSupport::TestCase
  test "parses HPB bank authentication and encryption public keys" do
    bank_x = OpenSSL::PKey::RSA.generate(2048)
    bank_e = OpenSSL::PKey::RSA.generate(2048)

    public_keys = Billing::EBICS::Btf::BankPublicKeys.new(
      host_id: "multivia",
      order_data: hpb_order_data(bank_x: bank_x, bank_e: bank_e))

    assert_equal %w[MULTIVIA.E002 MULTIVIA.X002], public_keys.keys.keys.sort
    assert_equal bank_x.n, public_keys.keys.fetch("MULTIVIA.X002").n
    assert_equal 2048, public_keys.metadata.dig("MULTIVIA.X002", "bits")
    assert_equal "bank", public_keys.metadata.dig("MULTIVIA.E002", "role")
    assert public_keys.metadata.dig("MULTIVIA.E002", "public_digest").present?
  end

  test "rejects non-H005 HPB response order data" do
    bank_x = OpenSSL::PKey::RSA.generate(2048)
    bank_e = OpenSSL::PKey::RSA.generate(2048)

    public_keys = Billing::EBICS::Btf::BankPublicKeys.new(
      host_id: "multivia",
      order_data: hpb_order_data(bank_x: bank_x, bank_e: bank_e, namespace: "urn:org:ebics:H004"))

    assert_raises Billing::EBICS::UnsupportedOperation do
      public_keys.keys
    end
  end

  test "rejects unsupported bank key versions" do
    bank_x = OpenSSL::PKey::RSA.generate(2048)
    bank_e = OpenSSL::PKey::RSA.generate(2048)

    public_keys = Billing::EBICS::Btf::BankPublicKeys.new(
      host_id: "multivia",
      order_data: hpb_order_data(bank_x: bank_x, bank_e: bank_e, authentication_version: "X001"))

    assert_raises Billing::EBICS::UnsupportedOperation do
      public_keys.keys
    end
  end

  private

  def hpb_order_data(bank_x:, bank_e:, namespace: "urn:org:ebics:H005", authentication_version: "X002", encryption_version: "E002")
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <HPBResponseOrderData xmlns="#{namespace}" xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
        <AuthenticationPubKeyInfo>
          #{rsa_key_value(bank_x)}
          <AuthenticationVersion>#{authentication_version}</AuthenticationVersion>
        </AuthenticationPubKeyInfo>
        <EncryptionPubKeyInfo>
          #{rsa_key_value(bank_e)}
          <EncryptionVersion>#{encryption_version}</EncryptionVersion>
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

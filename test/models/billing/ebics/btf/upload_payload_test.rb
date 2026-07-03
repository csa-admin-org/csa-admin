# frozen_string_literal: true

require "test_helper"
require "base64"
require "epics"
require "nokogiri"
require "openssl"
require "zlib"

class Billing::EBICS::Btf::UploadPayloadTest < ActiveSupport::TestCase
  SIGNATURE_NAMESPACE = Billing::EBICS::Btf::UploadPayload::SIGNATURE_NAMESPACE

  test "encrypts order data and S002 signature data" do
    client = synthetic_epics_client
    payload = Billing::EBICS::Btf::UploadPayload.new(
      client: client,
      document: "<Document>pain</Document>\n",
      transaction_key: "1234567890abcdef")

    assert_equal "<Document>pain</Document>\n", decrypt(payload.encrypted_order_data, payload.transaction_key)

    signature_xml = decrypt(payload.encrypted_signature_data, payload.transaction_key)
    signature = Nokogiri::XML(signature_xml)

    assert_equal "UserSignatureData", signature.root.name
    assert_equal SIGNATURE_NAMESPACE, signature.root.namespace.href
    assert_equal "A006", signature.at_xpath("//*[local-name() = 'SignatureVersion']").text
    assert_equal "PARTNERID", signature.at_xpath("//*[local-name() = 'PartnerID']").text
    assert_equal "USERID", signature.at_xpath("//*[local-name() = 'UserID']").text
    assert_not_empty signature.at_xpath("//*[local-name() = 'SignatureValue']").text
    assert_equal Base64.strict_encode64(OpenSSL::Digest::SHA256.digest("<Document>pain</Document>")), payload.data_digest
  end

  private

  def synthetic_epics_client
    ::Epics::Client.setup(
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "USERID",
      "PARTNERID",
      2048).tap { |client|
        client.keys["HOSTID.X002"] = client.x
        client.keys["HOSTID.E002"] = client.e
      }
  end

  def decrypt(data, transaction_key)
    encrypted = Base64.strict_decode64(data)
    cipher = OpenSSL::Cipher.new("aes-128-cbc")
    cipher.decrypt
    cipher.padding = 0
    cipher.key = transaction_key
    cipher.iv = "\0" * cipher.iv_len
    inflated = Zlib::Inflate.inflate(cipher.update(encrypted) + cipher.final)
    inflated.delete_suffix("\0")
  end
end

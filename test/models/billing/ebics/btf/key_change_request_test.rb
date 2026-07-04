# frozen_string_literal: true

require "test_helper"
require "base64"
require "nokogiri"
require "openssl"

class Billing::EBICS::Btf::KeyChangeRequestTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE

  test "builds a deterministic H005 HCS initialisation request" do
    request = Billing::EBICS::Btf::KeyChangeRequest.new(
      client: FakeClient.new,
      target_client: FakeClient.new,
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-01T12:00:00Z",
      signer: FakeSigner.new,
      payload: FakePayload.new)
    xml = Nokogiri::XML(request.to_xml)

    assert_equal "H005", xml.root["Version"]
    assert_equal "HCS", text(xml, "//h:AdminOrderType")
    assert xml.at_xpath("//h:StandardOrderParams", h: H005_NAMESPACE)
    assert_nil xml.at_xpath("//h:BTUOrderParams", h: H005_NAMESPACE)
    assert_equal "1", text(xml, "//h:NumSegments")
    assert_equal "ENCRYPTED-TRANSACTION-KEY", text(xml, "//h:TransactionKey")
    assert_equal "ENCRYPTED-SIGNATURE-DATA", text(xml, "//h:SignatureData")
    assert_equal "DATA-DIGEST", text(xml, "//h:DataDigest")
    assert_equal "A006", xml.at_xpath("//h:DataDigest", h: H005_NAMESPACE)["SignatureVersion"]
    assert_equal "SIGNATURE", xml.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text
  end

  test "real signer digests all authenticated HCS upload nodes" do
    client = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
    target_client = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(keysize: 4096))
    request = Billing::EBICS::Btf::KeyChangeRequest.new(
      client: client,
      target_client: target_client,
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-01T12:00:00Z",
      payload: FakePayload.new)
    xml = Nokogiri::XML(request.to_xml)

    authenticated = xml.xpath("//*[@authenticate='true']").map(&:canonicalize).join
    assert_equal 3, xml.xpath("//*[@authenticate='true']").size
    assert_equal Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(authenticated)),
      xml.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).text
    assert client.x.key.verify(
      OpenSSL::Digest::SHA256.new,
      Base64.strict_decode64(xml.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text),
      xml.at_xpath("//ds:SignedInfo", ds: XMLDSIG_NAMESPACE).canonicalize)
  end

  private

  def text(xml, xpath)
    xml.at_xpath(xpath, h: H005_NAMESPACE).text
  end

  class FakeSigner
    def sign(xml)
      doc = Nokogiri::XML(xml)
      doc.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).content = "DIGEST"
      doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = "SIGNATURE"
      doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
    end
  end

  class FakePayload
    def encrypted_transaction_key = "ENCRYPTED-TRANSACTION-KEY"
    def encrypted_signature_data = "ENCRYPTED-SIGNATURE-DATA"
    def encrypted_order_data = "ENCRYPTED-ORDER-DATA"
    def data_digest = "DATA-DIGEST"
    def signature_version = "A006"
  end

  class FakeClient
    attr_reader :host_id, :partner_id, :user_id

    def initialize
      @host_id = "RAIFCHEC"
      @partner_id = "PARTNERID"
      @user_id = "USERID"
    end

    def bank_x = FakeKey.new("BANK-X-DIGEST")
    def bank_e = FakeKey.new("BANK-E-DIGEST")
  end

  class FakeKey
    def initialize(public_digest)
      @public_digest = public_digest
    end

    attr_reader :public_digest
  end
end

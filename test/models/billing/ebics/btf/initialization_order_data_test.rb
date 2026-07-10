# frozen_string_literal: true

require "test_helper"
require "base64"
require "nokogiri"
require "openssl"
require "zlib"

class Billing::EBICS::Btf::InitializationOrderDataTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE
  SIGNATURE_NAMESPACE = Billing::EBICS::Btf::UploadPayload::SIGNATURE_NAMESPACE

  test "builds INI signature public-key order data" do
    document = Nokogiri::XML(order_data("INI"))

    assert_equal "SignaturePubKeyOrderData", document.root.name
    assert_equal SIGNATURE_NAMESPACE, document.root.namespace.href
    assert_equal "PARTNERID", text(document, "//s:PartnerID")
    assert_equal "USERID", text(document, "//s:UserID")
    assert_equal "A006", text(document, "//s:SignatureVersion")
    assert_equal 1, document.xpath("//ds:X509Certificate", namespaces).size
    assert_equal 1, document.xpath("//ds:KeyValue", namespaces).size
    assert_empty document.xpath("//*[local-name()='PubKeyValue']")
    assert_empty document.xpath("//*[local-name()='TimeStamp']")
  end

  test "builds HIA authentication and encryption order data" do
    document = Nokogiri::XML(order_data("HIA"))

    assert_equal "HIARequestOrderData", document.root.name
    assert_equal H005_NAMESPACE, document.root.namespace.href
    assert_equal "X002", text(document, "//h:AuthenticationVersion")
    assert_equal "E002", text(document, "//h:EncryptionVersion")
    assert_equal 2, document.xpath("//ds:X509Certificate", namespaces).size
    assert_equal 2, document.xpath("//ds:KeyValue", namespaces).size
    assert_empty document.xpath("//*[local-name()='PubKeyValue']")
  end

  test "wraps INI order data in an unsecured H005 request" do
    request = Billing::EBICS::Btf::InitializationRequest.new(
      client: client,
      order_type: "INI",
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-05T10:00:00Z",
      certificate_issued_at: issued_at)
    document = Nokogiri::XML(request.to_xml)
    order_data = Zlib::Inflate.inflate(Base64.strict_decode64(text(document, "//h:OrderData")))

    assert_equal "ebicsUnsecuredRequest", document.root.name
    assert_equal "H005", document.root["Version"]
    assert_equal "INI", text(document, "//h:AdminOrderType")
    assert_equal "#{H005_NAMESPACE} ebics_keymgmt_request_H005.xsd", document.root["xsi:schemaLocation"]
    assert_nil document.at_xpath("//h:Nonce", namespaces)
    assert_nil document.at_xpath("//h:Timestamp", namespaces)
    assert_nil document.at_xpath("//h:StandardOrderParams", namespaces)
    assert_nil document.at_xpath("//h:TransactionPhase", namespaces)
    assert_nil document.at_xpath("//h:BankPubKeyDigests", namespaces)
    assert_nil document.at_xpath("//h:AuthSignature", namespaces)
    assert_equal "SignaturePubKeyOrderData", Nokogiri::XML(order_data).root.name
    assert_equal SIGNATURE_NAMESPACE, Nokogiri::XML(order_data).root.namespace.href
  end

  test "builds signed HPB no-bank-digest request" do
    request = Billing::EBICS::Btf::NoPubKeyDigestsRequest.new(
      client: client,
      order_type: "HPB",
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-05T10:00:00Z",
      signer: FakeSigner.new)
    document = Nokogiri::XML(request.to_xml)

    assert_equal "ebicsNoPubKeyDigestsRequest", document.root.name
    assert_equal "HPB", text(document, "//h:AdminOrderType")
    assert_nil document.at_xpath("//h:BankPubKeyDigests", namespaces)
    assert_equal "SIGNATURE", document.at_xpath("//ds:SignatureValue", namespaces).text
  end

  private

  def order_data(order_type)
    Billing::EBICS::Btf::InitializationOrderData.new(
      client: client,
      order_type: order_type,
      certificate_issued_at: issued_at).to_xml
  end

  def client
    @client ||= Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(key_material: {
      "A006" => OpenSSL::PKey::RSA.generate(2048),
      "X002" => OpenSSL::PKey::RSA.generate(2048),
      "E002" => OpenSSL::PKey::RSA.generate(2048)
    }))
  end

  def issued_at
    Time.utc(2026, 7, 5, 10, 0, 0)
  end

  def text(document, xpath)
    document.at_xpath(xpath, namespaces).text
  end

  def namespaces
    {
      h: H005_NAMESPACE,
      ds: XMLDSIG_NAMESPACE,
      s: SIGNATURE_NAMESPACE
    }
  end

  class FakeSigner
    def sign(xml)
      document = Nokogiri::XML(xml)
      document.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).content = "DIGEST"
      document.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = "SIGNATURE"
      document.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
    end
  end
end

# frozen_string_literal: true

require "test_helper"
require "base64"
require "epics"
require "nokogiri"
require "openssl"

class Billing::EBICS::Btf::DownloadRequestTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE

  test "builds a deterministic H005 BTD CAMT.054 v04 request" do
    request = Billing::EBICS::Btf::DownloadRequest.new(
      client: FakeClient.new,
      operation: operation(Billing::EBICS::Btf::Presets.swiss_camt054),
      from: Date.new(2026, 6, 1),
      to: Date.new(2026, 6, 30),
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-01T12:00:00Z",
      signer: FakeSigner.new)

    assert_equal canonical_xml(file_fixture("ebics/h005_btd_camt054_v04_request.xml").read),
      canonical_xml(request.to_xml)
  end

  test "omits optional service option when it is not configured" do
    xml = Nokogiri::XML(unsigned_request_xml)

    assert_nil xml.at_xpath("//h:ServiceOption", h: H005_NAMESPACE)
  end

  test "signs generated XML with the participant X002 key" do
    client = synthetic_epics_client
    request = Billing::EBICS::Btf::DownloadRequest.new(
      client: client,
      operation: operation(Billing::EBICS::Btf::Presets.german_camt053),
      from: "2026-06-01",
      to: "2026-06-30",
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-01T12:00:00Z")

    xml = Nokogiri::XML(request.to_xml)
    signature_value = xml.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text
    signed_info = xml.at_xpath("//ds:SignedInfo", ds: XMLDSIG_NAMESPACE).canonicalize

    assert_not_empty xml.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).text
    assert_not_empty signature_value
    assert client.x.key.verify(OpenSSL::Digest::SHA256.new, Base64.decode64(signature_value), signed_info)
    assert_equal "BTD", xml.at_xpath("//h:AdminOrderType", h: H005_NAMESPACE).text
    assert_equal "EOP", xml.at_xpath("//h:ServiceName", h: H005_NAMESPACE).text
    assert_equal "DE", xml.at_xpath("//h:Scope", h: H005_NAMESPACE).text
    assert_equal "08", xml.at_xpath("//h:MsgName", h: H005_NAMESPACE)["version"]
  end

  private

  def unsigned_request_xml
    Billing::EBICS::Btf::DownloadRequest.new(
      client: FakeClient.new,
      operation: operation(Billing::EBICS::Btf::Presets.swiss_camt054),
      from: "2026-06-01",
      to: "2026-06-30",
      signer: FakeSigner.new).unsigned_xml
  end

  def operation(attributes)
    Billing::EBICS::Operation.btf(attributes)
  end

  def canonical_xml(xml)
    Nokogiri::XML(xml) { |config| config.noblanks }.canonicalize
  end

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

  class FakeSigner
    def sign(xml)
      doc = Nokogiri::XML(xml)
      doc.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).content = "DIGEST"
      doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = "SIGNATURE"
      doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
    end
  end

  class FakeClient
    attr_reader :host_id, :partner_id, :user_id

    def initialize
      @host_id = "RAIFCHEC"
      @partner_id = "PARTNERID"
      @user_id = "USERID"
    end

    def bank_x
      FakeKey.new("BANK-X-DIGEST")
    end

    def bank_e
      FakeKey.new("BANK-E-DIGEST")
    end
  end

  class FakeKey
    def initialize(public_digest)
      @public_digest = public_digest
    end

    attr_reader :public_digest
  end
end

# frozen_string_literal: true

require "test_helper"
require "nokogiri"

class Billing::EBICS::Btf::AdminRequestTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE

  test "builds a deterministic H005 HTD request" do
    request = Billing::EBICS::Btf::AdminRequest.new(
      client: FakeClient.new,
      order_type: "HTD",
      nonce: "0123456789abcdef0123456789abcdef",
      timestamp: "2026-07-01T12:00:00Z",
      signer: FakeSigner.new)
    xml = Nokogiri::XML(request.to_xml)

    assert_equal "H005", xml.root["Version"]
    assert_equal "HTD", xml.at_xpath("//h:AdminOrderType", h: H005_NAMESPACE).text
    assert xml.at_xpath("//h:StandardOrderParams", h: H005_NAMESPACE)
    assert_nil xml.at_xpath("//h:BTDOrderParams", h: H005_NAMESPACE)
    assert_equal "SIGNATURE", xml.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text
  end

  test "rejects unsupported admin orders" do
    request = Billing::EBICS::Btf::AdminRequest.new(
      client: FakeClient.new,
      order_type: "HPB",
      signer: FakeSigner.new)

    error = assert_raises(Billing::EBICS::UnsupportedOperation) { request.to_xml }

    assert_includes error.message, "HAA and HTD"
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
      @host_id = "MULTIVIA"
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

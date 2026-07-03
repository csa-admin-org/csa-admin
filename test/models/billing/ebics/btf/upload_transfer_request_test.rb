# frozen_string_literal: true

require "test_helper"
require "nokogiri"

class Billing::EBICS::Btf::UploadTransferRequestTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE

  test "builds a deterministic H005 BTU transfer request" do
    request = Billing::EBICS::Btf::UploadTransferRequest.new(
      client: FakeClient.new,
      transaction_id: "TX123",
      payload: FakePayload.new,
      signer: FakeSigner.new)
    xml = Nokogiri::XML(request.to_xml)

    assert_equal "H005", xml.root["Version"]
    assert_equal "TX123", text(xml, "//h:TransactionID")
    assert_equal "Transfer", text(xml, "//h:TransactionPhase")
    assert_equal "1", text(xml, "//h:SegmentNumber")
    assert_equal "true", xml.at_xpath("//h:SegmentNumber", h: H005_NAMESPACE)["lastSegment"]
    assert_equal "ENCRYPTED-ORDER-DATA", text(xml, "//h:OrderData")
    assert_equal "SIGNATURE", xml.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text
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
    def encrypted_order_data = "ENCRYPTED-ORDER-DATA"
  end

  class FakeClient
    attr_reader :host_id

    def initialize
      @host_id = "MULTIVIA"
    end
  end
end

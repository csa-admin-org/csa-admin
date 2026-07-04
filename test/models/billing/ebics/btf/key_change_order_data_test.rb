# frozen_string_literal: true

require "test_helper"
require "base64"
require "nokogiri"
require "openssl"

class Billing::EBICS::Btf::KeyChangeOrderDataTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE
  SIGNATURE_NAMESPACE = Billing::EBICS::Btf::UploadPayload::SIGNATURE_NAMESPACE

  test "builds HCS request order data for all pending participant keys" do
    client = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(keysize: 4096))
    document = Nokogiri::XML(Billing::EBICS::Btf::KeyChangeOrderData.new(client: client).to_xml)

    assert_equal "HCSRequestOrderData", document.root.name
    assert_equal H005_NAMESPACE, document.root.namespace.href
    assert_equal "PARTNERID", text(document, "//h:PartnerID")
    assert_equal "USERID", text(document, "//h:UserID")
    assert_equal "X002", text(document, "//h:AuthenticationVersion")
    assert_equal "E002", text(document, "//h:EncryptionVersion")
    assert_equal "A006", document.at_xpath("//esig:SignatureVersion", namespaces).text
    assert_equal 3, document.xpath("//ds:X509IssuerSerial", namespaces).size
    assert_equal 3, document.xpath("//ds:X509Certificate", namespaces).size
    assert_equal 3, document.xpath("//ds:RSAKeyValue", namespaces).size

    certificates = document.xpath("//ds:X509Certificate", namespaces).map { |node|
      OpenSSL::X509::Certificate.new(Base64.strict_decode64(node.text))
    }
    assert certificates.all? { |certificate| certificate.public_key.n.to_i.bit_length == 4096 }
  end

  private

  def text(document, xpath)
    document.at_xpath(xpath, namespaces).text
  end

  def namespaces
    {
      h: H005_NAMESPACE,
      ds: XMLDSIG_NAMESPACE,
      esig: SIGNATURE_NAMESPACE
    }
  end
end

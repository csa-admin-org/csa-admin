# frozen_string_literal: true

require "test_helper"
require "base64"
require "epics"
require "nokogiri"
require "openssl"

class Billing::EBICS::Btf::RequestSignerTest < ActiveSupport::TestCase
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE

  test "digests authenticated nodes and signs SignedInfo with participant X002" do
    key_store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
    signed_xml = Billing::EBICS::Btf::RequestSigner.new(key_store).sign(unsigned_xml)
    doc = Nokogiri::XML(signed_xml)

    authenticated = doc.xpath("//*[@authenticate='true']").map(&:canonicalize).join
    assert_equal Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(authenticated)), digest_value(doc)

    assert key_store.x.key.verify(
      OpenSSL::Digest::SHA256.new,
      Base64.strict_decode64(signature_value(doc)),
      signed_info(doc))
  end

  test "matches epics signer output for existing encrypted key blobs" do
    epics_client = synthetic_epics_client
    key_store = Billing::EBICS::KeyStore.new(credentials_from(epics_client))

    assert_equal canonical_xml(sign_with_epics(epics_client)),
      canonical_xml(Billing::EBICS::Btf::RequestSigner.new(key_store).sign(unsigned_xml))
  end

  private

  def unsigned_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsRequest xmlns="urn:org:ebics:H005" xmlns:ds="#{XMLDSIG_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static>
            <HostID>HOSTID</HostID>
          </static>
        </header>
        <AuthSignature>
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
            <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
            <ds:Reference URI="#xpointer(//*[@authenticate='true'])">
              <ds:Transforms>
                <ds:Transform Algorithm="http://www.w3.org/TR/2001/REC-xml-c14n-20010315"/>
              </ds:Transforms>
              <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
              <ds:DigestValue/>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue/>
        </AuthSignature>
        <body/>
      </ebicsRequest>
    XML
  end

  def sign_with_epics(client)
    signer = ::Epics::Signer.new(client, unsigned_xml)
    signer.digest!
    signer.sign!
    signer.doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
  end

  def credentials_from(client)
    {
      "keys" => client.send(:dump_keys),
      "secret" => "secret",
      "url" => "https://ebics.example.test",
      "host_id" => "HOSTID",
      "participant_id" => "USERID",
      "client_id" => "PARTNERID"
    }
  end

  def canonical_xml(xml)
    Nokogiri::XML(xml) { |config| config.noblanks }.canonicalize
  end

  def digest_value(doc)
    doc.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).text
  end

  def signature_value(doc)
    doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).text
  end

  def signed_info(doc)
    doc.at_xpath("//ds:SignedInfo", ds: XMLDSIG_NAMESPACE).canonicalize
  end
end

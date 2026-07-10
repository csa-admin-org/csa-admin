# frozen_string_literal: true

require "test_helper"
require "base64"
require "nokogiri"
require "openssl"

class Billing::EBICS::Btf::ResponseSignatureVerifierTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::Response::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE
  SHA256_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::SHA256_ALGORITHM
  XML_C14N_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::XML_C14N_ALGORITHM
  RSA_SHA256_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::RSA_SHA256_ALGORITHM
  REFERENCE_URI = Billing::EBICS::Btf::ResponseSignatureVerifier::REFERENCE_URI

  test "accepts the exact signed H005 response profile" do
    response = response_for(signed_response_xml)

    assert_predicate response, :digest_valid?
    assert_predicate response, :signature_valid?
  end

  test "rejects a digest injected outside the signed info" do
    response = response_for(signed_response_xml { |doc|
      injected = Nokogiri::XML::DocumentFragment.parse(
        %(<ds:DigestValue xmlns:ds="#{XMLDSIG_NAMESPACE}">#{signed_digest_for(doc)}</ds:DigestValue>))
      doc.root.at_xpath("./h:header", h: H005_NAMESPACE).add_previous_sibling(injected)
    })

    assert_not_predicate response, :digest_valid?
    assert_not_predicate response, :signature_valid?
  end

  test "rejects authenticated response tampering" do
    response = response_for(signed_response_xml { |doc|
      doc.at_xpath("//h:TransactionID", h: H005_NAMESPACE).content = "EVIL"
    })

    assert_not_predicate response, :digest_valid?
    assert_predicate response, :signature_valid?
  end

  test "rejects malformed XMLDSIG profile variations" do
    assert_invalid_signature { |doc| doc.at_xpath("//ds:Reference", ds: XMLDSIG_NAMESPACE)["URI"] = "#xpointer(//h:header)" }
    assert_invalid_signature { |doc| doc.at_xpath("//ds:Reference", ds: XMLDSIG_NAMESPACE).add_next_sibling(doc.at_xpath("//ds:Reference", ds: XMLDSIG_NAMESPACE).dup) }
    assert_invalid_signature { |doc| doc.at_xpath("//h:AuthSignature", h: H005_NAMESPACE).add_child(%(<ds:KeyInfo xmlns:ds="#{XMLDSIG_NAMESPACE}"/>)) }
    assert_invalid_signature { |doc| doc.root["Revision"] = "2" }
    assert_invalid_signature { |doc| doc.at_xpath("//ds:DigestMethod", ds: XMLDSIG_NAMESPACE)["Algorithm"] = "http://www.w3.org/2000/09/xmldsig#sha1" }
    assert_invalid_signature { |doc| doc.xpath("//*[@authenticate='true']").remove_attr("authenticate") }
    assert_invalid_signature { |doc| doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = "not base64" }
  end

  test "rejects unsecured responses when signatures are required" do
    response = response_for(signed_response_xml(root: "ebicsUnsecuredResponse"))

    assert_not_predicate response, :digest_valid?
    assert_not_predicate response, :signature_valid?
  end

  private

  def assert_invalid_signature
    response = response_for(signed_response_xml { |doc| yield doc })

    assert_not response.digest_valid? && response.signature_valid?
  end

  def response_for(xml)
    Billing::EBICS::Btf::Response.new(client: client, xml: xml)
  end

  def signed_response_xml(root: "ebicsResponse")
    doc = Nokogiri::XML(response_xml(root: root))
    append_signature_shell(doc)
    sign_response!(doc)
    yield doc if block_given?
    serialize(doc)
  end

  def append_signature_shell(doc)
    doc.root.add_child(Nokogiri::XML::DocumentFragment.parse(<<~XML))
      <AuthSignature xmlns="#{H005_NAMESPACE}" xmlns:ds="#{XMLDSIG_NAMESPACE}">
        <ds:SignedInfo>
          <ds:CanonicalizationMethod Algorithm="#{XML_C14N_ALGORITHM}"/>
          <ds:SignatureMethod Algorithm="#{RSA_SHA256_ALGORITHM}"/>
          <ds:Reference URI="#{REFERENCE_URI}">
            <ds:Transforms>
              <ds:Transform Algorithm="#{XML_C14N_ALGORITHM}"/>
            </ds:Transforms>
            <ds:DigestMethod Algorithm="#{SHA256_ALGORITHM}"/>
            <ds:DigestValue/>
          </ds:Reference>
        </ds:SignedInfo>
        <ds:SignatureValue/>
      </AuthSignature>
    XML
  end

  def sign_response!(doc)
    doc.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).content = signed_digest_for(doc)
    doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = Base64.strict_encode64(
      bank_x.sign(OpenSSL::Digest::SHA256.new, doc.at_xpath("//ds:SignedInfo", ds: XMLDSIG_NAMESPACE).canonicalize))
  end

  def signed_digest_for(doc)
    Base64.strict_encode64(OpenSSL::Digest::SHA256.digest(
      doc.xpath("//*[@authenticate='true']").map(&:canonicalize).join))
  end

  def response_xml(root: "ebicsResponse")
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <#{root} xmlns="#{H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static>
            <TransactionID>TX123</TransactionID>
          </static>
          <mutable>
            <TransactionPhase>Initialisation</TransactionPhase>
            <SegmentNumber lastSegment="true">1</SegmentNumber>
            <ReturnCode>000000</ReturnCode>
            <ReportText>OK</ReportText>
          </mutable>
        </header>
        <body>
          <DataTransfer>
            <DataEncryptionInfo authenticate="true"/>
          </DataTransfer>
        </body>
      </#{root}>
    XML
  end

  def serialize(doc)
    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
  end

  def client
    @client ||= Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(bank_x: bank_x, bank_e: bank_e))
  end

  def bank_x
    @bank_x ||= OpenSSL::PKey::RSA.generate(2048)
  end

  def bank_e
    @bank_e ||= OpenSSL::PKey::RSA.generate(2048)
  end
end

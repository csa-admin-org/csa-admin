# frozen_string_literal: true

require "base64"
require "nokogiri"
require "openssl"

module EbicsSignedResponseHelper
  H005_NAMESPACE = Billing::EBICS::Btf::Response::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE
  REFERENCE_URI = Billing::EBICS::Btf::ResponseSignatureVerifier::REFERENCE_URI

  def signed_h005_response_xml(
    bank_x:,
    bank_e_digest: nil,
    transaction_id: "0123456789abcdef0123456789abcdef",
    technical_return_code: "000000",
    business_return_code: "000000",
    report_text: "OK",
    transaction_phase: "Initialisation",
    segment_number: nil,
    last_segment: nil,
    order_id: nil,
    transaction_key: nil,
    order_data: nil)
    transaction_id_xml = transaction_id ? "<TransactionID>#{transaction_id}</TransactionID>" : ""
    segment_number_xml = segment_number ? "<SegmentNumber lastSegment=\"#{last_segment}\">#{segment_number}</SegmentNumber>" : ""
    order_id_xml = order_id ? "<OrderID>#{order_id}</OrderID>" : ""
    data_transfer_xml = data_transfer_xml(
      bank_e_digest:,
      transaction_key:,
      order_data:)

    doc = Nokogiri::XML(<<~XML)
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsResponse xmlns="#{H005_NAMESPACE}" Version="H005">
        <header authenticate="true">
          <static>#{transaction_id_xml}</static>
          <mutable>
            <TransactionPhase>#{transaction_phase}</TransactionPhase>
            #{segment_number_xml}
            #{order_id_xml}
            <ReturnCode>#{technical_return_code}</ReturnCode>
            <ReportText>#{report_text}</ReportText>
          </mutable>
        </header>
        <body>
          #{data_transfer_xml}
          <ReturnCode authenticate="true">#{business_return_code}</ReturnCode>
        </body>
      </ebicsResponse>
    XML
    append_auth_signature!(doc)
    sign_h005_response!(doc, bank_x)
    yield doc if block_given?

    doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
  end

  private

  def data_transfer_xml(bank_e_digest:, transaction_key:, order_data:)
    return "" unless transaction_key || order_data

    raise ArgumentError, "bank_e_digest is required for encrypted order data" unless bank_e_digest

    transaction_key_xml = transaction_key ? "<TransactionKey>#{transaction_key}</TransactionKey>" : ""
    order_data_xml = order_data ? "<OrderData>#{order_data}</OrderData>" : ""

    <<~XML
      <DataTransfer>
        <DataEncryptionInfo authenticate="true">
          <EncryptionPubKeyDigest Version="E002" Algorithm="#{Billing::EBICS::Btf::DownloadRequest::SHA256_ALGORITHM}">#{bank_e_digest}</EncryptionPubKeyDigest>
          #{transaction_key_xml}
        </DataEncryptionInfo>
        #{order_data_xml}
      </DataTransfer>
    XML
  end

  def append_auth_signature!(doc)
    doc.root.at_xpath("./h:body", h: H005_NAMESPACE).add_previous_sibling(
      Nokogiri::XML::DocumentFragment.parse(<<~XML))
        <AuthSignature xmlns="#{H005_NAMESPACE}" xmlns:ds="#{XMLDSIG_NAMESPACE}">
          <ds:SignedInfo>
            <ds:CanonicalizationMethod Algorithm="#{Billing::EBICS::Btf::DownloadRequest::XML_C14N_ALGORITHM}"/>
            <ds:SignatureMethod Algorithm="#{Billing::EBICS::Btf::DownloadRequest::RSA_SHA256_ALGORITHM}"/>
            <ds:Reference URI="#{REFERENCE_URI}">
              <ds:Transforms>
                <ds:Transform Algorithm="#{Billing::EBICS::Btf::DownloadRequest::XML_C14N_ALGORITHM}"/>
              </ds:Transforms>
              <ds:DigestMethod Algorithm="#{Billing::EBICS::Btf::DownloadRequest::SHA256_ALGORITHM}"/>
              <ds:DigestValue/>
            </ds:Reference>
          </ds:SignedInfo>
          <ds:SignatureValue/>
        </AuthSignature>
      XML
  end

  def sign_h005_response!(doc, bank_x)
    doc.at_xpath("//ds:DigestValue", ds: XMLDSIG_NAMESPACE).content = Base64.strict_encode64(
      OpenSSL::Digest::SHA256.digest(doc.xpath("//*[@authenticate='true']").map(&:canonicalize).join))
    doc.at_xpath("//ds:SignatureValue", ds: XMLDSIG_NAMESPACE).content = Base64.strict_encode64(
      bank_x.sign(
        OpenSSL::Digest::SHA256.new,
        doc.at_xpath("//ds:SignedInfo", ds: XMLDSIG_NAMESPACE).canonicalize))
  end
end

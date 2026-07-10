# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::Btf::SchemaValidationTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::H005_NAMESPACE
  XMLDSIG_NAMESPACE = Billing::EBICS::Btf::DownloadRequest::XMLDSIG_NAMESPACE
  SHA256_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::SHA256_ALGORITHM
  XML_C14N_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::XML_C14N_ALGORITHM
  RSA_SHA256_ALGORITHM = Billing::EBICS::Btf::DownloadRequest::RSA_SHA256_ALGORITHM
  VALID_TRANSACTION_ID = "0123456789abcdef0123456789abcdef"

  test "generated H005 request XML validates against official schemas" do
    assert_valid_ebics_h005_xml download_request.to_xml, :request, "BTD request should be schema-valid"
    assert_valid_ebics_h005_xml upload_request.to_xml, :request, "BTU request should be schema-valid"
    assert_valid_ebics_h005_xml upload_transfer_request.to_xml, :request, "BTU transfer request should be schema-valid"
    assert_valid_ebics_h005_xml transfer_request.to_xml, :request, "BTD transfer request should be schema-valid"
    assert_valid_ebics_h005_xml receipt_request.to_xml, :request, "Receipt request should be schema-valid"
    assert_valid_ebics_h005_xml admin_request("HTD").to_xml, :request, "HTD admin request should be schema-valid"
    assert_valid_ebics_h005_xml admin_request("HAA").to_xml, :request, "HAA admin request should be schema-valid"
    assert_valid_ebics_h005_xml key_change_request.to_xml, :request, "HCS key-change request should be schema-valid"

    assert_valid_ebics_h005_xml no_pub_key_digests_request.to_xml,
      :key_management_request,
      "HPB no-bank-digest request should be schema-valid"
    assert_valid_ebics_h005_xml initialization_request("INI").to_xml,
      :key_management_request,
      "INI request should be schema-valid"
    assert_valid_ebics_h005_xml initialization_request("HIA").to_xml,
      :key_management_request,
      "HIA request should be schema-valid"
  end

  test "generated H005 order-data XML validates against official schemas" do
    assert_valid_ebics_h005_xml initialization_order_data("INI").to_xml,
      :signature,
      "INI S002 order data should be schema-valid"
    assert_valid_ebics_h005_xml initialization_order_data("HIA").to_xml,
      :orders,
      "HIA order data should be schema-valid"
    assert_valid_ebics_h005_xml key_change_order_data.to_xml,
      :orders,
      "HCS order data should be schema-valid"
    assert_valid_ebics_h005_xml upload_payload.order_signature_xml,
      :signature,
      "S002 upload signature data should be schema-valid"
  end

  test "representative H005 response XML validates against official schemas" do
    assert_valid_ebics_h005_xml response_xml,
      :response,
      "Signed EBICS response should be schema-valid"
    assert_valid_ebics_h005_xml key_management_response_xml,
      :key_management_response,
      "Key-management response should be schema-valid"
  end

  test "committed EBICS XML fixtures validate against their official schemas" do
    Rails.root.glob("test/fixtures/files/ebics/**/*.xml").each do |path|
      next if path.to_s.include?("/schemas/")

      assert_valid_ebics_h005_xml path.read, schema_for(path), "#{path.relative_path_from(Rails.root)} should be schema-valid"
    end
  end

  private

  def schema_for(path)
    document = Nokogiri::XML(path.read)

    case document.root.name
    when "ebicsRequest"
      :request
    when "ebicsUnsecuredRequest", "ebicsNoPubKeyDigestsRequest"
      :key_management_request
    when "ebicsResponse"
      :response
    when "ebicsKeyManagementResponse"
      :key_management_response
    when "SignaturePubKeyOrderData", "UserSignatureData"
      :signature
    else
      :orders
    end
  end

  def download_request
    Billing::EBICS::Btf::DownloadRequest.new(
      client: client,
      operation: operation(Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04")),
      from: "2026-06-01",
      to: "2026-06-30")
  end

  def upload_request
    Billing::EBICS::Btf::UploadRequest.new(
      client: client,
      operation: operation(Billing::EBICS::Btf::Presets.sepa_direct_debit_upload(scope: "DE", container: "XML")),
      document: "<Document>pain</Document>")
  end

  def upload_transfer_request
    Billing::EBICS::Btf::UploadTransferRequest.new(
      client: client,
      transaction_id: VALID_TRANSACTION_ID,
      payload: upload_payload)
  end

  def transfer_request
    Billing::EBICS::Btf::TransferRequest.new(
      client: client,
      transaction_id: VALID_TRANSACTION_ID,
      segment_number: 2)
  end

  def receipt_request
    Billing::EBICS::Btf::ReceiptRequest.new(
      client: client,
      transaction_id: VALID_TRANSACTION_ID)
  end

  def admin_request(order_type)
    Billing::EBICS::Btf::AdminRequest.new(client: client, order_type: order_type)
  end

  def key_change_request
    Billing::EBICS::Btf::KeyChangeRequest.new(client: client, target_client: target_client)
  end

  def no_pub_key_digests_request
    Billing::EBICS::Btf::NoPubKeyDigestsRequest.new(client: client, order_type: "HPB")
  end

  def initialization_request(order_type)
    Billing::EBICS::Btf::InitializationRequest.new(client: client, order_type: order_type)
  end

  def initialization_order_data(order_type)
    Billing::EBICS::Btf::InitializationOrderData.new(client: client, order_type: order_type)
  end

  def key_change_order_data
    Billing::EBICS::Btf::KeyChangeOrderData.new(client: target_client)
  end

  def upload_payload
    @upload_payload ||= Billing::EBICS::Btf::UploadPayload.new(client: client, document: "<Document>pain</Document>")
  end

  def response_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsResponse xmlns="#{H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static><TransactionID>#{VALID_TRANSACTION_ID}</TransactionID></static>
          <mutable>
            <TransactionPhase>Transfer</TransactionPhase>
            <SegmentNumber lastSegment="true">1</SegmentNumber>
            <ReturnCode>000000</ReturnCode>
            <ReportText>OK</ReportText>
          </mutable>
        </header>
        #{auth_signature_xml}
        <body>
          <DataTransfer>
            <DataEncryptionInfo authenticate="true">
              <EncryptionPubKeyDigest Version="E002" Algorithm="#{SHA256_ALGORITHM}">#{client.bank_e.public_digest}</EncryptionPubKeyDigest>
              <TransactionKey>#{upload_payload.encrypted_transaction_key}</TransactionKey>
            </DataEncryptionInfo>
            <OrderData>#{upload_payload.encrypted_order_data}</OrderData>
          </DataTransfer>
          <ReturnCode authenticate="true">000000</ReturnCode>
        </body>
      </ebicsResponse>
    XML
  end

  def key_management_response_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsKeyManagementResponse xmlns="#{H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static/>
          <mutable>
            <ReturnCode>000000</ReturnCode>
            <ReportText>OK</ReportText>
          </mutable>
        </header>
        <body>
          <ReturnCode authenticate="true">000000</ReturnCode>
        </body>
      </ebicsKeyManagementResponse>
    XML
  end

  def auth_signature_xml
    <<~XML
      <AuthSignature xmlns="#{H005_NAMESPACE}" xmlns:ds="#{XMLDSIG_NAMESPACE}">
        <ds:SignedInfo>
          <ds:CanonicalizationMethod Algorithm="#{XML_C14N_ALGORITHM}"/>
          <ds:SignatureMethod Algorithm="#{RSA_SHA256_ALGORITHM}"/>
          <ds:Reference URI="#xpointer(//*[@authenticate='true'])">
            <ds:Transforms><ds:Transform Algorithm="#{XML_C14N_ALGORITHM}"/></ds:Transforms>
            <ds:DigestMethod Algorithm="#{SHA256_ALGORITHM}"/>
            <ds:DigestValue>AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=</ds:DigestValue>
          </ds:Reference>
        </ds:SignedInfo>
        <ds:SignatureValue>U0lHTkFUVVJF</ds:SignatureValue>
      </AuthSignature>
    XML
  end

  def operation(attributes)
    Billing::EBICS::Operation.btf(attributes)
  end

  def client
    @client ||= Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
  end

  def target_client
    @target_client ||= Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(keysize: 2048))
  end
end

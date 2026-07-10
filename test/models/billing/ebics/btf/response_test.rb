# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"
require "securerandom"
require "stringio"
require "zip"
require "zlib"

class Billing::EBICS::Btf::ResponseTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::Response::H005_NAMESPACE

  test "decrypts transport data and extracts XML files from a business ZIP container" do
    xml_files = [ "<Document>one</Document>", "<Document>two</Document>" ]
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(order_data: encrypted_order_data(zip(xml_files))))

    assert response.ok?
    assert_equal "TX123", response.transaction_id
    assert_equal "1", response.segment_number
    assert response.last_segment?
    assert_equal xml_files, response.files(container: "ZIP")
  end

  test "returns raw order data when no business ZIP container is requested" do
    payload = "<Document>single</Document>"
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(order_data: encrypted_order_data(payload)))

    assert_equal [ payload ], response.files
  end

  test "detects accepted no-data responses" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(business_return_code: "090005", report_text: "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"))

    assert response.business_error?
    assert response.no_download_data?
    assert_equal "090005", response.return_code
  end

  test "does not classify provider text as no-data without the exact return code" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(report_text: "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"))

    assert_not_predicate response, :no_download_data?
  end

  test "rejects ambiguous critical response fields" do
    xml = response_xml.sub("<ReturnCode>000000</ReturnCode>", "<ReturnCode>000000</ReturnCode><ReturnCode>061099</ReturnCode>")
    response = Billing::EBICS::Btf::Response.new(client: client, xml: xml)

    assert_not_predicate response, :critical_fields_unique?
  end

  test "limits encoded order data segments before decoding" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(order_data: Base64.strict_encode64("123456789")))

    with_response_limit(:MAX_ENCODED_ORDER_DATA_BYTES, 4) do
      assert_raises(Billing::EBICS::Btf::Response::OrderDataTooLarge) do
        response.order_data_encrypted
      end
    end
  end

  test "parses upload order id" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(order_id: "A001"))

    assert_equal "A001", response.order_id
  end

  test "recognizes only standard and key-management H005 response roots" do
    response = Billing::EBICS::Btf::Response.new(client: client, xml: response_xml)
    unsecured_response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(root: "ebicsUnsecuredResponse"))
    html = Billing::EBICS::Btf::Response.new(client: client, xml: "<html>Not EBICS</html>")

    assert_predicate response, :standard_h005?
    assert_not_predicate unsecured_response, :h005?
    assert_not_predicate html, :h005?
  end

  test "detects technical errors" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(return_code: "061099"))

    assert response.technical_error?
    assert_not response.ok?
  end

  private

  def client
    @client ||= Billing::EBICS::KeyStore.new(synthetic_ebics_credentials)
  end

  def with_response_limit(name, value)
    response = Billing::EBICS::Btf::Response
    original = response.const_get(name)
    response.send(:remove_const, name)
    response.const_set(name, value)
    yield
  ensure
    response.send(:remove_const, name)
    response.const_set(name, original)
  end

  def encrypted_order_data(payload)
    compressed = Zlib::Deflate.deflate(payload)
    cipher = OpenSSL::Cipher.new("aes-128-cbc")
    cipher.encrypt
    cipher.padding = 0
    cipher.key = transaction_key

    Base64.strict_encode64(cipher.update(zero_pad(compressed)) + cipher.final)
  end

  def response_xml(order_data: nil, return_code: "000000", business_return_code: nil, report_text: "OK", order_id: nil, root: "ebicsResponse")
    transaction_key_xml = order_data ? "<TransactionKey>#{encrypted_transaction_key}</TransactionKey>" : ""
    order_data_xml = order_data ? "<OrderData>#{order_data}</OrderData>" : ""
    body_return_code_xml = business_return_code ? "<ReturnCode>#{business_return_code}</ReturnCode>" : ""
    order_id_xml = order_id ? "<OrderID>#{order_id}</OrderID>" : ""

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
            #{order_id_xml}
            <ReturnCode>#{return_code}</ReturnCode>
            <ReportText>#{report_text}</ReportText>
          </mutable>
        </header>
        <body>
          #{body_return_code_xml}
          <DataTransfer>
            <DataEncryptionInfo authenticate="true">
              #{transaction_key_xml}
            </DataEncryptionInfo>
            #{order_data_xml}
          </DataTransfer>
        </body>
      </#{root}>
    XML
  end

  def encrypted_transaction_key
    Base64.strict_encode64(client.e.key.public_encrypt(transaction_key))
  end

  def transaction_key
    "1234567890abcdef"
  end

  def zero_pad(data)
    padding = data.bytesize % 16
    return data if padding.zero?

    data + ("\0" * (16 - padding))
  end

  def zip(files)
    Zip::OutputStream.write_buffer do |zip|
      files.each_with_index do |content, index|
        zip.put_next_entry("file-#{index}.xml")
        zip.write(content)
      end
    end.string
  end
end

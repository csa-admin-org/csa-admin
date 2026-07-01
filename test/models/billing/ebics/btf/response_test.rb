# frozen_string_literal: true

require "test_helper"
require "base64"
require "epics"
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

  test "detects technical errors" do
    response = Billing::EBICS::Btf::Response.new(
      client: client,
      xml: response_xml(return_code: "061099"))

    assert response.technical_error?
    assert_not response.ok?
  end

  private

  def client
    @client ||= ::Epics::Client.setup(
      "secret",
      "https://ebics.example.test",
      "HOSTID",
      "USERID",
      "PARTNERID",
      2048)
  end

  def encrypted_order_data(payload)
    compressed = Zlib::Deflate.deflate(payload)
    cipher = OpenSSL::Cipher.new("aes-128-cbc")
    cipher.encrypt
    cipher.padding = 0
    cipher.key = transaction_key

    Base64.strict_encode64(cipher.update(zero_pad(compressed)) + cipher.final)
  end

  def response_xml(order_data: nil, return_code: "000000", business_return_code: nil, report_text: "OK")
    transaction_key_xml = order_data ? "<TransactionKey>#{encrypted_transaction_key}</TransactionKey>" : ""
    order_data_xml = order_data ? "<OrderData>#{order_data}</OrderData>" : ""
    body_return_code_xml = business_return_code ? "<ReturnCode>#{business_return_code}</ReturnCode>" : ""

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsResponse xmlns="#{H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static>
            <TransactionID>TX123</TransactionID>
          </static>
          <mutable>
            <TransactionPhase>Initialisation</TransactionPhase>
            <SegmentNumber lastSegment="true">1</SegmentNumber>
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
      </ebicsResponse>
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

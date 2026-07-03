# frozen_string_literal: true

require "test_helper"
require "base64"
require "epics"
require "openssl"
require "zip"
require "zlib"

class Billing::EBICS::BtfClientTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::Response::H005_NAMESPACE

  test "uses legacy client only as a key-loading bridge" do
    legacy_client = LegacyClientStub.new
    client = Billing::EBICS::BtfClient.new(credentials, legacy_client: legacy_client)

    assert_same legacy_client.epics_client, client.client
  end

  test "builds signed BTD download request XML" do
    client = Billing::EBICS::BtfClient.new(
      credentials,
      legacy_client: LegacyClientStub.new,
      request_options: {
        nonce: "0123456789abcdef0123456789abcdef",
        timestamp: "2026-07-01T12:00:00Z",
        signer: FakeSigner.new
      })

    xml = client.download_request_xml(operation, from: "2026-06-01", to: "2026-06-30")

    assert_includes xml, "<AdminOrderType>BTD</AdminOrderType>"
    assert_includes xml, "<ServiceName>REP</ServiceName>"
    assert_includes xml, "<MsgName version=\"04\">camt.054</MsgName>"
    assert_includes xml, "<ds:SignatureValue>SIGNATURE</ds:SignatureValue>"
  end

  test "manual test download can acknowledge segmented BTD data" do
    xml_files = [ "<Document>one</Document>", "<Document>two</Document>" ]
    encrypted_segments = encrypted_order_data_segments(zip(xml_files))
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: false, transaction_key: true, order_data: encrypted_segments.first),
      response_xml(segment_number: 2, last_segment: true, order_data: encrypted_segments.last),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    result = client.test_download(operation, from: "2026-06-01", to: "2026-06-30", acknowledge: true)

    assert_equal "data_acknowledged", result.status
    assert_equal xml_files, result.files
    assert result.acknowledged
    assert_equal 0, result.receipt_code
    assert_equal 3, transport.requests.size
    assert_includes transport.requests.first, "<TransactionPhase>Initialisation</TransactionPhase>"
    assert_includes transport.requests.second, "<TransactionPhase>Transfer</TransactionPhase>"
    assert_includes transport.requests.second, "<SegmentNumber lastSegment=\"false\">2</SegmentNumber>"
    assert_includes transport.requests.third, "<TransactionPhase>Receipt</TransactionPhase>"
    assert_includes transport.requests.third, "<ReceiptCode>0</ReceiptCode>"
  end

  test "plain BTF downloads remain disabled to avoid pre-processing acknowledgements" do
    client = btf_client

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.download(operation, from: "2026-06-01", to: "2026-06-30")
    end

    assert_includes error.message, "download_and_process"
  end

  test "download and process acknowledges only after processing succeeds" do
    xml_files = [ "<Document>one</Document>" ]
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(zip(xml_files))),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    result = client.download_and_process(operation, from: "2026-06-01", to: "2026-06-30") do |files|
      assert_equal xml_files, files
      assert_equal 1, transport.requests.size
      :processed
    end

    assert_equal :processed, result
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.second, "<ReceiptCode>0</ReceiptCode>"
  end

  test "download and process sends failure receipt when processing fails" do
    xml_files = [ "<Document>one</Document>" ]
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(zip(xml_files))),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    error = assert_raises(RuntimeError) do
      client.download_and_process(operation, from: "2026-06-01", to: "2026-06-30") do
        raise "processing failed"
      end
    end

    assert_equal "processing failed", error.message
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.second, "<ReceiptCode>1</ReceiptCode>"
  end

  test "download and process does not send failure receipt after successful processing" do
    xml_files = [ "<Document>one</Document>" ]
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(zip(xml_files))),
      response_xml(order_data: nil, return_code: "061099", report_text: "receipt failed")
    ])
    client = btf_client(transport: transport)

    assert_raises(Billing::EBICS::TechnicalError) do
      client.download_and_process(operation, from: "2026-06-01", to: "2026-06-30") do
        :processed
      end
    end

    assert_equal 2, transport.requests.size
    assert_includes transport.requests.second, "<ReceiptCode>0</ReceiptCode>"
  end

  test "test download treats no-data as a successful authorization check" do
    transport = TransportStub.new([ no_data_response_xml ])
    client = btf_client(transport: transport)

    result = client.test_download(operation, from: "2026-06-01", to: "2026-06-30")

    assert_equal "no_data", result.status
    assert_empty result.files
    assert result.acknowledged
    assert_nil result.receipt_code
    assert_equal 1, transport.requests.size
  end

  test "test download can avoid acknowledging returned data" do
    xml_files = [ "<Document>one</Document>" ]
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(zip(xml_files))),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    result = client.test_download(operation, from: "2026-06-01", to: "2026-06-30")

    assert_equal "data_available_not_acknowledged", result.status
    assert_equal xml_files, result.files
    assert_not result.acknowledged
    assert_equal 1, result.receipt_code
    assert_includes transport.requests.second, "<ReceiptCode>1</ReceiptCode>"
  end

  test "test download accepts bank postprocess-skipped response to negative receipt" do
    xml_files = [ "<Document>one</Document>" ]
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(zip(xml_files))),
      negative_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    result = client.test_download(operation, from: "2026-06-01", to: "2026-06-30")

    assert_equal "data_available_not_acknowledged", result.status
    assert_equal xml_files, result.files
    assert_not result.acknowledged
    assert_equal 1, result.receipt_code
  end

  test "maps H005 no-data response through the EBICS boundary error" do
    client = btf_client

    error = assert_raises(Billing::EBICS::NoDownloadDataAvailable) do
      client.files_from_response(operation, no_data_response_xml)
    end

    assert_includes error.message, "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "rejects order-type operations" do
    client = btf_client

    assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.download(Billing::EBICS::Operation.order_type("Z54"), from: "2026-06-01", to: "2026-06-30")
    end
  end

  private

  def btf_client(transport: TransportStub.new([]))
    Billing::EBICS::BtfClient.new(
      credentials,
      legacy_client: LegacyClientStub.new(synthetic_epics_client),
      request_options: {
        nonce: "0123456789abcdef0123456789abcdef",
        timestamp: "2026-07-01T12:00:00Z",
        signer: FakeSigner.new
      },
      transport: transport,
      verify_signatures: false)
  end

  def operation
    Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04"))
  end

  def credentials
    {
      "keys" => "keys",
      "secret" => "secret",
      "url" => "https://ebics.example.test",
      "host_id" => "HOSTID",
      "participant_id" => "PARTNERID",
      "client_id" => "USERID"
    }
  end

  def synthetic_epics_client
    @synthetic_epics_client ||= ::Epics::Client.setup(
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

  def encrypted_order_data_segments(payload)
 encrypted = encrypted_order_data(payload)
    midpoint = encrypted.bytesize / 2
    [ encrypted.byteslice(0, midpoint), encrypted.byteslice(midpoint, encrypted.bytesize - midpoint) ]
  end

  def encrypted_order_data(payload)
    compressed = Zlib::Deflate.deflate(payload)
    cipher = OpenSSL::Cipher.new("aes-128-cbc")
    cipher.encrypt
    cipher.padding = 0
    cipher.key = transaction_key
    cipher.update(zero_pad(compressed)) + cipher.final
  end

  def response_xml(segment_number: 1, last_segment: true, transaction_key: false, order_data: nil, return_code: "000000", business_return_code: nil, report_text: "OK")
    transaction_key_xml = transaction_key ? "<TransactionKey>#{encrypted_transaction_key}</TransactionKey>" : ""
    order_data_xml = order_data ? "<OrderData>#{Base64.strict_encode64(order_data)}</OrderData>" : ""
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
            <SegmentNumber lastSegment="#{last_segment}">#{segment_number}</SegmentNumber>
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

  def no_data_response_xml
    response_xml(business_return_code: "090005", report_text: "EBICS_NO_DOWNLOAD_DATA_AVAILABLE")
  end

  def ok_receipt_response_xml
    response_xml(order_data: nil)
  end

  def negative_receipt_response_xml
    response_xml(
      order_data: nil,
      return_code: "061101",
      business_return_code: "000000",
      report_text: "[EBICS_DOWNLOAD_POSTPROCESS_SKIPPED] Negative acknowledgement received")
  end

  def encrypted_transaction_key
    Base64.strict_encode64(synthetic_epics_client.e.key.public_encrypt(transaction_key))
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

  class FakeSigner
    def sign(xml)
      doc = Nokogiri::XML(xml)
      doc.at_xpath("//*[local-name() = 'DigestValue']").content = "DIGEST"
      doc.at_xpath("//*[local-name() = 'SignatureValue']").content = "SIGNATURE"
      doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
    end
  end

  class TransportStub
    attr_reader :requests

    def initialize(responses)
      @responses = responses
      @requests = []
    end

    def post(_url, request_xml)
      requests << request_xml
      @responses.shift
    end
  end

  class LegacyClientStub
    attr_reader :epics_client

    def initialize(epics_client = EpicsClientStub.new)
      @epics_client = epics_client
    end

    def client
      epics_client
    end
  end

  class EpicsClientStub
    attr_reader :host_id, :partner_id, :user_id

    def initialize
      @host_id = "HOSTID"
      @partner_id = "PARTNERID"
      @user_id = "USERID"
    end

    def bank_x
      KeyStub.new("BANK-X-DIGEST")
    end

    def bank_e
      KeyStub.new("BANK-E-DIGEST")
    end
  end

  class KeyStub
    def initialize(public_digest)
      @public_digest = public_digest
    end

    attr_reader :public_digest
  end
end

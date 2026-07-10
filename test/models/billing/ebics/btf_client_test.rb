# frozen_string_literal: true

require "test_helper"
require "base64"
require "openssl"
require "zip"
require "zlib"

class Billing::EBICS::BtfClientTest < ActiveSupport::TestCase
  H005_NAMESPACE = Billing::EBICS::Btf::Response::H005_NAMESPACE

  test "uses app-owned key store for H005 requests" do
    key_store = KeyStoreStub.new
    client = Billing::EBICS::BtfClient.new(credentials, key_store: key_store)

    assert_same key_store, client.client
  end

  test "builds signed BTD download request XML" do
    client = Billing::EBICS::BtfClient.new(
      credentials,
      key_store: KeyStoreStub.new,
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

  test "uploads H005 BTU data through initialisation and transfer" do
    transport = TransportStub.new([
      response_xml(order_id: "A001"),
      response_xml(order_id: "B002")
    ])
    client = btf_client(transport: transport)

    result = client.upload(btu_operation, document: "<Document>pain</Document>")

    assert_equal [ "TX123", "B002" ], result
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.first, "<AdminOrderType>BTU</AdminOrderType>"
    assert_includes transport.requests.first, "<BTUOrderParams>"
    assert_includes transport.requests.first, "<ServiceName>SDD</ServiceName>"
    assert_includes transport.requests.first, "<ServiceOption>COR</ServiceOption>"
    assert_includes transport.requests.first, "<MsgName version=\"08\">pain.008</MsgName>"
    assert_includes transport.requests.first, "<SignatureData authenticate=\"true\">"
    assert_includes transport.requests.first, "<DataDigest SignatureVersion=\"A006\">"
    assert_includes transport.requests.second, "<TransactionPhase>Transfer</TransactionPhase>"
    assert_includes transport.requests.second, "<SegmentNumber lastSegment=\"true\">1</SegmentNumber>"
    assert_includes transport.requests.second, "<OrderData>"
    assert_not_includes transport.requests.join, "<Document>pain</Document>"
  end

  test "submits HCS key change through initialisation and transfer" do
    transport = TransportStub.new([
      response_xml(order_id: "A001"),
      response_xml(order_id: "B002")
    ])
    client = btf_client(transport: transport)
    target_key_store = Billing::EBICS::KeyStore.new(synthetic_ebics_credentials(keysize: 4096))

    result = client.key_change(target_key_store: target_key_store)

    assert_equal({ "transaction_id" => "TX123", "order_id" => "B002" }, result.to_h)
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.first, "<AdminOrderType>HCS</AdminOrderType>"
    assert_includes transport.requests.first, "<StandardOrderParams/>"
    assert_not_includes transport.requests.first, "<BTUOrderParams>"
    assert_includes transport.requests.first, "<SignatureData authenticate=\"true\">"
    assert_includes transport.requests.first, "<DataDigest SignatureVersion=\"A006\">"
    assert_includes transport.requests.second, "<TransactionPhase>Transfer</TransactionPhase>"
    assert_includes transport.requests.second, "<OrderData>"
    assert_not_includes transport.requests.join, "HCSRequestOrderData"
    assert_not_includes transport.requests.join, "PRIVATE KEY"
  end

  test "BTU upload returns the initialisation order id when transfer omits one" do
    transport = TransportStub.new([
      response_xml(order_id: "A001"),
      response_xml(order_id: nil)
    ])
    client = btf_client(transport: transport)

    assert_equal [ "TX123", "A001" ], client.upload(btu_operation, document: "<Document>pain</Document>")
  end

  test "BTU upload reports and raises when initialisation response has no transaction id" do
    error = ErrorRecorder.new
    transport = TransportStub.new([ response_xml(transaction_id: nil, order_id: "A001") ])
    client = btf_client(transport: transport, error_reporter: error)

    raised = assert_raises(Billing::EBICS::TechnicalError) do
      client.upload(btu_operation, document: "<Document>pain</Document>")
    end

    assert_includes raised.message, "Missing EBICS BTU initialisation TransactionID"
    message, context = error.unexpected_errors.first
    assert_equal "Missing EBICS BTU initialisation TransactionID", message
    assert_equal "BTU", context.dig("operation", "order_type")
    assert_equal "pain.008", context.dig("operation", "message_name")
    refute context.dig("response", "transaction_id_present")
    assert context.dig("response", "order_id_present")
  end

  test "BTU upload reports and raises when no order id is returned" do
    error = ErrorRecorder.new
    transport = TransportStub.new([
      response_xml(order_id: nil),
      response_xml(order_id: nil)
    ])
    client = btf_client(transport: transport, error_reporter: error)

    raised = assert_raises(Billing::EBICS::TechnicalError) do
      client.upload(btu_operation, document: "<Document>pain</Document>")
    end

    assert_includes raised.message, "Missing EBICS BTU upload OrderID"
    message, context = error.unexpected_errors.first
    assert_equal "Missing EBICS BTU upload OrderID", message
    assert_equal "BTU", context.dig("operation", "order_type")
    refute context.dig("response", "order_id_present")
  end

  test "BTU upload rejects non-upload operations" do
    client = btf_client

    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.upload(operation, document: "<Document>pain</Document>")
    end

    assert_includes error.message, "BTU upload"
  end

  test "fetches H005 admin order data and acknowledges the metadata response" do
    htd_xml = "<HTDResponseOrderData><UserInfo><OrderInfo><AdminOrderType>BTD</AdminOrderType></OrderInfo></UserInfo></HTDResponseOrderData>"
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data(htd_xml)),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    result = client.admin_order("HTD")

    assert_equal htd_xml, result.order_data
    assert result.receipt_sent
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.first, "<AdminOrderType>HTD</AdminOrderType>"
    assert_includes transport.requests.first, "<StandardOrderParams/>"
    assert_includes transport.requests.second, "<ReceiptCode>0</ReceiptCode>"
  end

  test "admin order sends failure receipt for unexpected order data" do
    error = ErrorRecorder.new
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data("<Document>unexpected</Document>")),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport, error_reporter: error)

    raised = assert_raises(Billing::EBICS::BtfClient::AdminOrderDataError) do
      client.admin_order("HTD")
    end

    assert_includes raised.message, "Unexpected HTD response order data"
    message, context = error.unexpected_errors.first
    assert_equal "Unexpected EBICS admin-order response data", message
    assert_equal "HTD", context.fetch("admin_order_type")
    assert_equal "HTDResponseOrderData", context.fetch("expected_root")
    assert_equal "Document", context.fetch("root")
    assert_equal 2, transport.requests.size
    assert_includes transport.requests.second, "<ReceiptCode>1</ReceiptCode>"
    assert_not_includes transport.requests.second, "<ReceiptCode>0</ReceiptCode>"
  end

  test "HPB bank key fetch sends failure receipt when key data is invalid" do
    transport = TransportStub.new([
      response_xml(segment_number: 1, last_segment: true, transaction_key: true, order_data: encrypted_order_data("<Document>unexpected</Document>")),
      ok_receipt_response_xml
    ])
    client = btf_client(transport: transport)

    assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.fetch_bank_public_keys
    end

    assert_equal 2, transport.requests.size
    assert_includes transport.requests.first, "<AdminOrderType>HPB</AdminOrderType>"
    assert_includes transport.requests.second, "<ReceiptCode>1</ReceiptCode>"
    assert_not_includes transport.requests.second, "<ReceiptCode>0</ReceiptCode>"
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

  test "parses EBICS response bodies from non-success HTTP responses" do
    transport = TransportStub.new([ http_error(response_xml(return_code: "061099", report_text: "EBICS_INVALID_USER_OR_USER_STATE")) ])
    client = btf_client(transport: transport)

    error = assert_raises(Billing::EBICS::TechnicalError) do
      client.submit_initialization_order("INI")
    end

    assert_includes error.message, "EBICS_INVALID_USER_OR_USER_STATE"
  end

  test "rejects non-H005 EBICS responses" do
    transport = TransportStub.new([ "<html>Not EBICS</html>" ])
    client = btf_client(transport: transport)

    error = assert_raises(Billing::EBICS::TechnicalError) do
      client.submit_initialization_order("INI")
    end

    assert_includes error.message, "Invalid EBICS H005 response"
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

  test "signature verification still allows H005 no-data return codes to surface" do
    client = btf_client(verify_signatures: true)

    error = assert_raises(Billing::EBICS::NoDownloadDataAvailable) do
      client.files_from_response(operation, no_data_response_xml)
    end

    assert_includes error.message, "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "signature verification rejects successful unsigned responses" do
    client = btf_client(verify_signatures: true)

    error = assert_raises(Billing::EBICS::TechnicalError) do
      client.files_from_response(
        operation,
        response_xml(transaction_key: true, order_data: encrypted_order_data(zip([ "<Document>one</Document>" ]))))
    end

    assert_instance_of Billing::EBICS::BtfClient::VerificationError, error.original_error
    assert_equal "Invalid EBICS response signature", error.message
  end

  test "transport rejects non-HTTPS EBICS endpoints" do
    assert_transport_endpoint_error "http://ebics.example.test"
    assert_transport_endpoint_error "https://user:secret@ebics.example.test"
    assert_transport_endpoint_error "https://"
  end

  test "BTF ZIP payload accepts legitimate bank batches with many files" do
    files = 101.times.map { |index| "<Document>#{index}</Document>" }

    assert_equal files, btf_client.files_from_response(
      operation,
      response_xml(transaction_key: true, order_data: encrypted_order_data(zip(files))))
  end

  test "BTF ZIP payload rejects too many files" do
    with_payload_limit(:MAX_ZIP_FILES, 1) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        btf_client.files_from_response(
          operation,
          response_xml(transaction_key: true, order_data: encrypted_order_data(zip(%w[one two]))))
      end

      assert_includes error.message, "too many files (2/1)"
    end
  end

  test "BTF ZIP payload rejects oversized entries" do
    with_payload_limit(:MAX_ZIP_ENTRY_BYTES, 8) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        btf_client.files_from_response(
          operation,
          response_xml(transaction_key: true, order_data: encrypted_order_data(zip([ "123456789" ]))))
      end

      assert_includes error.message, "EBICS ZIP entry exceeds"
    end
  end

  test "BTF ZIP payload rejects oversized totals" do
    with_payload_limit(:MAX_ZIP_TOTAL_BYTES, 8) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        btf_client.files_from_response(
          operation,
          response_xml(transaction_key: true, order_data: encrypted_order_data(zip(%w[12345 6789]))))
      end

      assert_includes error.message, "EBICS ZIP payload is too large"
    end
  end

  test "BTF payload rejects oversized inflated order data" do
    with_payload_limit(:MAX_INFLATED_ORDER_DATA_BYTES, 8) do
      error = assert_raises(Billing::EBICS::Btf::Payload::PayloadTooLarge) do
        btf_client.files_from_response(
          plain_operation,
          response_xml(transaction_key: true, order_data: encrypted_order_data("123456789")))
      end

      assert_includes error.message, "EBICS order data exceeds"
    end
  end

  private

  def btf_client(transport: TransportStub.new([]), error_reporter: ErrorRecorder.new, verify_signatures: false)
    Billing::EBICS::BtfClient.new(
      credentials,
      key_store: key_store,
      request_options: {
        nonce: "0123456789abcdef0123456789abcdef",
        timestamp: "2026-07-01T12:00:00Z",
        signer: FakeSigner.new
      },
      transport: transport,
      verify_signatures: verify_signatures,
      context: { "tenant" => "acme", "bank" => "Test Bank" },
      error_reporter: error_reporter)
  end

  def operation
    Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04"))
  end

  def plain_operation
    Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.camt054(service_name: "REP", scope: "CH", version: "04", container: nil))
  end

  def btu_operation
    Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.sepa_direct_debit_upload)
  end

  def credentials
    @credentials ||= synthetic_ebics_credentials
  end

  def key_store
    @key_store ||= Billing::EBICS::KeyStore.new(credentials)
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

  def response_xml(segment_number: 1, last_segment: true, transaction_key: false, order_data: nil, return_code: "000000", business_return_code: nil, report_text: "OK", order_id: nil, transaction_id: "TX123")
    transaction_key_xml = transaction_key ? "<TransactionKey>#{encrypted_transaction_key}</TransactionKey>" : ""
    order_data_xml = order_data ? "<OrderData>#{Base64.strict_encode64(order_data)}</OrderData>" : ""
    body_return_code_xml = business_return_code ? "<ReturnCode>#{business_return_code}</ReturnCode>" : ""
    order_id_xml = order_id ? "<OrderID>#{order_id}</OrderID>" : ""
    transaction_id_xml = transaction_id ? "<TransactionID>#{transaction_id}</TransactionID>" : ""

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsResponse xmlns="#{H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static>
            #{transaction_id_xml}
          </static>
          <mutable>
            <TransactionPhase>Initialisation</TransactionPhase>
            <SegmentNumber lastSegment="#{last_segment}">#{segment_number}</SegmentNumber>
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

  def http_error(body)
    response = Struct.new(:code, :message, :body).new("500", "Internal Server Error", body)
    Billing::EBICS::Btf::Transport::HTTPError.new(response)
  end

  def encrypted_transaction_key
    Base64.strict_encode64(key_store.e.key.public_encrypt(transaction_key))
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

  def assert_transport_endpoint_error(url)
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      Billing::EBICS::Btf::Transport.new.post(url, "<xml/>")
    end

    assert_includes error.message, "HTTPS without userinfo"
  end

  def with_payload_limit(name, value)
    payload = Billing::EBICS::Btf::Payload
    original = payload.const_get(name)
    payload.send(:remove_const, name)
    payload.const_set(name, value)
    yield
  ensure
    payload.send(:remove_const, name)
    payload.const_set(name, original)
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
      response = @responses.shift
      raise response if response.is_a?(Exception)

      response
    end
  end

  class KeyStoreStub
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

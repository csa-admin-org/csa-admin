# frozen_string_literal: true

require "test_helper"

class Billing::EBICS::BtfClientTest < ActiveSupport::TestCase
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

    xml = client.download_request_xml(
      Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.swiss_camt054),
      from: "2026-06-01",
      to: "2026-06-30")

    assert_includes xml, "<AdminOrderType>BTD</AdminOrderType>"
    assert_includes xml, "<ServiceName>REP</ServiceName>"
    assert_includes xml, "<MsgName version=\"04\">camt.054</MsgName>"
    assert_includes xml, "<ds:SignatureValue>SIGNATURE</ds:SignatureValue>"
  end

  test "runtime download path stays disabled until H005 transport is implemented" do
    client = Billing::EBICS::BtfClient.new(credentials, legacy_client: LegacyClientStub.new)
    error = assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.download(
        Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.swiss_camt054),
        from: "2026-06-01",
        to: "2026-06-30")
    end

    assert_includes error.message, "not connected to transfer/receipt handling yet"
  end

  test "maps H005 no-data response through the EBICS boundary error" do
    client = Billing::EBICS::BtfClient.new(credentials, legacy_client: LegacyClientStub.new)

    error = assert_raises(Billing::EBICS::NoDownloadDataAvailable) do
      client.files_from_response(
        Billing::EBICS::Operation.btf(Billing::EBICS::Btf::Presets.swiss_camt054),
        no_data_response_xml)
    end

    assert_includes error.message, "EBICS_NO_DOWNLOAD_DATA_AVAILABLE"
  end

  test "rejects order-type operations" do
    client = Billing::EBICS::BtfClient.new(credentials, legacy_client: LegacyClientStub.new)

    assert_raises(Billing::EBICS::UnsupportedOperation) do
      client.download(Billing::EBICS::Operation.order_type("Z54"), from: "2026-06-01", to: "2026-06-30")
    end
  end

  private

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

  def no_data_response_xml
    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsResponse xmlns="#{Billing::EBICS::Btf::Response::H005_NAMESPACE}" Version="H005" Revision="1">
        <header authenticate="true">
          <static>
            <TransactionID>TX123</TransactionID>
          </static>
          <mutable>
            <TransactionPhase>Initialisation</TransactionPhase>
            <ReturnCode>000000</ReturnCode>
            <ReportText>OK</ReportText>
          </mutable>
        </header>
        <body>
          <ReturnCode>090005</ReturnCode>
          <ReportText>EBICS_NO_DOWNLOAD_DATA_AVAILABLE</ReportText>
        </body>
      </ebicsResponse>
    XML
  end

  class FakeSigner
    def sign(xml)
      doc = Nokogiri::XML(xml)
      doc.at_xpath("//*[local-name() = 'DigestValue']").content = "DIGEST"
      doc.at_xpath("//*[local-name() = 'SignatureValue']").content = "SIGNATURE"
      doc.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
    end
  end

  class LegacyClientStub
    attr_reader :epics_client

    def initialize
      @epics_client = EpicsClientStub.new
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

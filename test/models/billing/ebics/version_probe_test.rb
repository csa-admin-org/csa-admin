# frozen_string_literal: true

require "test_helper"
require "nokogiri"

class Billing::EBICS::VersionProbeTest < ActiveSupport::TestCase
  H000_NAMESPACE = Billing::EBICS::VersionProbe::H000_NAMESPACE

  test "builds H000 HEV request and parses advertised versions" do
    transport = TransportStub.new(hev_response(
      versions: {
        "H004" => "02.50",
        "H005" => "03.00"
      }))

    result = probe(transport).check!(url: "https://ebics.example.test", host_id: "RAIFCHEC")
    url, xml = transport.requests.sole
    doc = Nokogiri::XML(xml)

    assert_equal "https://ebics.example.test", url
    assert_equal "ebicsHEVRequest", doc.root.name
    assert_equal H000_NAMESPACE, doc.root.namespace.href
    assert_equal "RAIFCHEC", doc.at_xpath("//h:HostID", h: H000_NAMESPACE).text
    assert_equal({ "H004" => "02.50", "H005" => "03.00" }, result.versions)
    assert_predicate result, :ok?
    assert_predicate result, :h005?
  end

  test "raises host ID error when HEV rejects the host" do
    transport = TransportStub.new(hev_response(return_code: "091011", report_text: "EBICS_INVALID_HOST_ID"))

    error = assert_raises(Billing::EBICS::VersionProbe::HostIDError) do
      probe(transport).check!(url: "https://ebics.example.test", host_id: "UNKNOWN")
    end

    assert_includes error.message, "HostID"
  end

  test "raises unsupported version error when H005 is not advertised" do
    transport = TransportStub.new(hev_response(versions: { "H004" => "02.50" }))

    error = assert_raises(Billing::EBICS::VersionProbe::UnsupportedVersionError) do
      probe(transport).check!(url: "https://ebics.example.test", host_id: "HOSTID")
    end

    assert_includes error.message, "H005"
  end

  test "raises endpoint error for non-HEV responses" do
    transport = TransportStub.new("<html>Not EBICS</html>")

    error = assert_raises(Billing::EBICS::VersionProbe::EndpointError) do
      probe(transport).check!(url: "https://example.test", host_id: "HOSTID")
    end

    assert_includes error.message, "Invalid EBICS HEV response"
  end

  test "parses EBICS HEV body from HTTP errors" do
    transport = TransportStub.new(http_error(hev_response(return_code: "091011", report_text: "EBICS_INVALID_HOST_ID")))

    assert_raises(Billing::EBICS::VersionProbe::HostIDError) do
      probe(transport).check!(url: "https://ebics.example.test", host_id: "UNKNOWN")
    end
  end

  test "raises endpoint error for HTTP errors without a body" do
    transport = TransportStub.new(http_error(""))

    assert_raises(Billing::EBICS::VersionProbe::EndpointError) do
      probe(transport).check!(url: "https://ebics.example.test", host_id: "HOSTID")
    end
  end

  private

  def probe(transport)
    Billing::EBICS::VersionProbe.new(transport: transport)
  end

  def hev_response(return_code: "000000", report_text: "OK", versions: { "H005" => "03.00" })
    version_xml = versions.map do |protocol, number|
      %(<VersionNumber ProtocolVersion="#{protocol}">#{number}</VersionNumber>)
    end.join("\n")

    <<~XML
      <?xml version="1.0" encoding="utf-8"?>
      <ebicsHEVResponse xmlns="#{H000_NAMESPACE}">
        <SystemReturnCode>
          <ReturnCode>#{return_code}</ReturnCode>
          <ReportText>#{report_text}</ReportText>
        </SystemReturnCode>
        #{version_xml}
      </ebicsHEVResponse>
    XML
  end

  def http_error(body)
    Billing::EBICS::Btf::Transport::HTTPError.new(HTTPResponseStub.new(body: body))
  end

  class TransportStub
    attr_reader :requests

    def initialize(response)
      @response = response
      @requests = []
    end

    def post(url, xml)
      requests << [ url, xml ]
      raise @response if @response.is_a?(Exception)

      @response
    end
  end

  class HTTPResponseStub
    attr_reader :body

    def initialize(body:)
      @body = body
    end

    def code = "400"
    def message = "Bad Request"
  end
end

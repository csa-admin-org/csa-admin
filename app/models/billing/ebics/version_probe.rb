# frozen_string_literal: true

require "net/http"
require "nokogiri"
require "openssl"

module Billing
  class EBICS
    class VersionProbe
      H000_NAMESPACE = "http://www.ebics.org/H000"
      H005_PROTOCOL = "H005"
      OK_CODE = "000000"
      INVALID_HOST_ID_CODE = "091011"
      NETWORK_ERRORS = [
        EOFError,
        Errno::ECONNREFUSED,
        Errno::EHOSTUNREACH,
        Errno::ENETUNREACH,
        Net::OpenTimeout,
        Net::ReadTimeout,
        OpenSSL::SSL::SSLError,
        SocketError
      ].freeze

      Result = Data.define(:versions, :return_code) do
        def h005? = versions.key?(H005_PROTOCOL)
        def ok? = return_code == OK_CODE
      end

      EndpointError = Class.new(UnsupportedOperation)
      HostIDError = Class.new(UnsupportedOperation)
      UnsupportedVersionError = Class.new(UnsupportedOperation)

      def initialize(transport: Btf::Transport.new)
        @transport = transport
      end

      def check!(url:, host_id:)
        result = response_from(post(url, request_xml(host_id)))
        raise HostIDError, "EBICS HEV rejected HostID" if result.return_code == INVALID_HOST_ID_CODE
        raise EndpointError, "EBICS HEV failed with return code #{result.return_code.presence || "unknown"}" unless result.ok?
        raise UnsupportedVersionError, "EBICS endpoint does not advertise H005" unless result.h005?

        result
      end

      private

      attr_reader :transport

      def post(url, xml)
        transport.post(url, xml)
      rescue Btf::Transport::HTTPError => e
        raise EndpointError, e.message if e.body.blank?

        e.body
      rescue *NETWORK_ERRORS
        raise EndpointError, "EBICS HEV request failed"
      end

      def request_xml(host_id)
        Nokogiri::XML::Builder.new do |xml|
          xml.ebicsHEVRequest(root_attributes) {
            xml.HostID host_id
          }
        end.to_xml(save_with: Nokogiri::XML::Node::SaveOptions::AS_XML, encoding: "utf-8")
      end

      def root_attributes
        {
          "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
          "xsi:schemaLocation" => "#{H000_NAMESPACE} #{H000_NAMESPACE}/ebics_hev.xsd",
          "xmlns" => H000_NAMESPACE
        }
      end

      def response_from(xml)
        doc = Nokogiri::XML(xml) { |config| config.nonet }
        raise EndpointError, "Invalid EBICS HEV response" unless hev_response?(doc)

        Result.new(
          versions: versions(doc),
          return_code: text(doc, "//h:SystemReturnCode/h:ReturnCode"))
      end

      def hev_response?(doc)
        doc.root&.name == "ebicsHEVResponse" && doc.root.namespace&.href == H000_NAMESPACE
      end

      def versions(doc)
        doc.xpath("//h:VersionNumber", h: H000_NAMESPACE).each_with_object({}) do |node, values|
          values[node["ProtocolVersion"]] = node.text
        end
      end

      def text(doc, xpath)
        doc.at_xpath(xpath, h: H000_NAMESPACE)&.text.to_s
      end
    end
  end
end

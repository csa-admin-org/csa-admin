# frozen_string_literal: true

require "net/http"
require "uri"

module Billing
  class EBICS
    module Btf
      class Transport
        MAX_RESPONSE_BYTES = 40 * 1024 * 1024

        class HTTPError < StandardError
          attr_reader :body

          def initialize(response, body: nil)
            @body = body || response.body.to_s
            super("HTTP #{response.code}")
          end
        end

        ResponseTooLarge = Class.new(StandardError)

        def post(url, xml)
          uri = endpoint_uri(url)
          response = body = nil
          http(uri).request(request(uri, xml)) do |http_response|
            response = http_response
            body = read_response_body(http_response)
          end
          raise HTTPError.new(response, body: body) unless response.is_a?(Net::HTTPSuccess)

          body
        end

        private

        def endpoint_uri(url)
          URI.parse(url.to_s).tap do |uri|
            unless uri.is_a?(URI::HTTPS) && uri.host.present? && uri.userinfo.blank?
              raise UnsupportedOperation, "EBICS endpoint URL must use HTTPS without userinfo"
            end
          end
        rescue URI::InvalidURIError
          raise UnsupportedOperation, "EBICS endpoint URL must use HTTPS without userinfo"
        end

        def http(uri)
          Net::HTTP.new(uri.host, uri.port).tap do |http|
            http.use_ssl = uri.scheme == "https"
            http.open_timeout = 30
            http.read_timeout = 60
          end
        end

        def request(uri, xml)
          Net::HTTP::Post.new(uri.request_uri, {
            "Content-Type" => "text/xml",
            "User-Agent" => "CSA Admin EBICS"
          }).tap { |request| request.body = xml }
        end

        def read_response_body(response)
          body = +""
          response.read_body do |chunk|
            body << chunk
            if body.bytesize > MAX_RESPONSE_BYTES
              raise ResponseTooLarge, "EBICS HTTP response exceeds #{MAX_RESPONSE_BYTES} bytes"
            end
          end
          body
        end
      end
    end
  end
end

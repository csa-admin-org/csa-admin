# frozen_string_literal: true

require "net/http"
require "uri"

module Billing
  class EBICS
    module Btf
      class Transport
        HTTPError = Class.new(StandardError)

        def post(url, xml)
          uri = URI(url)
          response = http(uri).request(request(uri, xml))
          raise HTTPError, "HTTP #{response.code} #{response.message}" unless response.is_a?(Net::HTTPSuccess)

          response.body
        end

        private

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
      end
    end
  end
end

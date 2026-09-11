# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module Query
  class Client
    class Error < StandardError; end

    DEFAULT_URL = "https://query.csa-admin.org"

    def initialize(token: ENV["CSA_ADMIN_API_TOKEN"], url: ENV.fetch("CSA_ADMIN_API_URL", DEFAULT_URL))
      raise Error, "CSA_ADMIN_API_TOKEN is missing" if token.to_s.empty?

      @token = token
      @url = url
    end

    def get(path, params = {})
      request(:get, path, params)
    end

    def post(path, params = {})
      request(:post, path, params)
    end

    private

    def request(method, path, params)
      uri = request_uri(path, method == :get ? params : {})
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"

      req = method == :post ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      req["Authorization"] = %(Token token="#{@token}")
      req["Accept"] = "application/json"
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(params) if method == :post && params.any?

      response = http.request(req)
      body = JSON.parse(response.body) rescue { "error" => response.body }
      raise Error, JSON.pretty_generate(body) unless response.is_a?(Net::HTTPSuccess)

      body
    end

    def request_uri(path, query)
      uri = URI.parse(@url)
      uri.path = path.start_with?("/") ? path : "/#{path}"
      uri.query = URI.encode_www_form(query) if query.any?
      uri
    end
  end
end

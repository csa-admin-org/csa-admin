# frozen_string_literal: true

require "net/http"

class Cap::Client
  def initialize(api_url: Cap.api_url, api_key: :default)
    @api_url = api_url.delete_suffix("/")
    @api_key = api_key == :default ? default_api_key : api_key
  end

  def create_key(name:, instrumentation:, block_automated_browsers:, cors_origins:)
    request(:post, "/server/keys",
      name: name,
      instrumentation: instrumentation,
      blockAutomatedBrowsers: block_automated_browsers,
      corsOrigins: cors_origins)
  end

  def update_key_config(site_key:, instrumentation:, block_automated_browsers:, cors_origins:)
    request(:put, "/server/keys/#{site_key}/config",
      instrumentation: instrumentation,
      blockAutomatedBrowsers: block_automated_browsers,
      corsOrigins: cors_origins)
  end

  private

  def default_api_key
    ENV["CAP_API_KEY"].presence || Rails.application.credentials.cap_api_key
  end

  def request(method, path, body)
    raise "Missing CAP_API_KEY or cap_api_key in credentials" if @api_key.blank?

    uri = URI("#{@api_url}#{path}")
    request = request_class(method).new(uri,
      "Authorization" => "Bot #{@api_key}",
      "Content-Type" => "application/json")
    request.body = body.to_json

    response = Net::HTTP.start(uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 3,
      read_timeout: 10) do |http|
      http.request(request)
    end

    parse_response(response)
  end

  def request_class(method)
    case method
    when :post then Net::HTTP::Post
    when :put then Net::HTTP::Put
    else raise ArgumentError, "Unsupported HTTP method: #{method}"
    end
  end

  def parse_response(response)
    body = JSON.parse(response.body)
    return body if response.is_a?(Net::HTTPSuccess)

    error = body.fetch("error", response.body)
    raise "Cap API request failed (#{response.code}): #{error}"
  rescue JSON::ParserError
    raise "Cap API request failed (#{response.code}): #{response.body}"
  end
end

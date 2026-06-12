# frozen_string_literal: true

require "net/http"

class Cap::Verifier
  def self.skip? = !Rails.env.production? && ENV["CAP_SKIP_VERIFY"] == "1"
  def self.verify(token) = new(Current.org, token).verify

  def initialize(org, token)
    @token = token
    @site_key = Cap.site_key(org)
    @secret_key = Cap.secret_key(org)
  end

  def verify
    return false if missing_keys? && !Rails.env.production?
    raise "Missing Cap keys for #{Tenant.current}" if missing_keys?

    verify_token
  end

  private

  def missing_keys? = @site_key.blank? || @secret_key.blank?

  def verify_token
    response = request_siteverify
    response.is_a?(Net::HTTPSuccess) && JSON.parse(response.body)["success"]
  rescue StandardError => e
    Rails.error.report(e)
    false
  end

  def request_siteverify
    uri = URI("#{Cap.api_url}/#{@site_key}/siteverify")
    request = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
    request.body = { secret: @secret_key, response: @token }.to_json

    Net::HTTP.start(uri.host, uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 3,
      read_timeout: 5) do |http|
      http.request(request)
    end
  end
end

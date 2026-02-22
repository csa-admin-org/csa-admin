# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "openssl"
require "base64"
require "ostruct"

module Billing
  class Bunq
    MaintenanceError = Class.new(StandardError)
    AuthenticationError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)

    GET_PAYMENTS_FROM = 1.month.ago
    API_URL = "https://api.bunq.com"

    def initialize(credentials)
      @credentials = credentials.symbolize_keys
      @base_uri = URI(API_URL)
      @http = nil
      @session_token = nil
    end

    def payments_data
      start_session!
      fetch_payments
    rescue MaintenanceError
      []
    end

    def sepa_direct_debit_upload(*args)
      raise NotImplementedError, "SEPA direct debit upload with bunq is not supported"
    end

    private

    def fetch_payments
      payments = []
      older_id = nil

      loop do
        batch = fetch_payment_batch(older_id)
        break if batch.empty?

        batch.each do |payment|
          payment_data = process_payment(payment)
          payments << payment_data if payment_data
        end

        older_id = batch.last["id"]
        break if reached_cutoff_date?(batch.last)
      end

      payments
    end

    def fetch_payment_batch(older_id)
      response = get_payments(older_id:)
      (response.dig("Response") || []).filter_map { |item| item["Payment"] }
    end

    def process_payment(payment)
      amount = BigDecimal(payment.dig("amount", "value") || "0")
      return unless amount.positive?

      description = payment["description"] || ""
      ref = Billing.reference.extract_ref(description)

      if ref && Billing.reference.valid?(ref)
        build_payment_data(payment, amount, ref)
      elsif Billing.reference.unknown?(ref || description)
        notify_unknown_reference(payment, amount, description)
        nil
      end
    end

    def build_payment_data(payment, amount, ref)
      payload = Billing.reference.payload(ref)
      PaymentData.new(
        origin: "bunq",
        member_id: payload[:member_id],
        invoice_id: payload[:invoice_id],
        amount: amount,
        date: parse_date(payment["created"]),
        fingerprint: payment["id"]
      )
    end

    def notify_unknown_reference(payment, amount, description)
      Rails.event.notify(:unknown_payment_reference,
        origin: "bunq",
        amount: amount,
        date: parse_date(payment["created"]),
        ref: description)
    end

    def reached_cutoff_date?(payment)
      date = parse_date(payment["created"])
      date && date < GET_PAYMENTS_FROM.to_date
    end

    def get_payments(older_id: nil)
      path = "/v1/user/#{user_id}/monetary-account/#{monetary_account_id}/payment"

      # bunq uses cursor-based pagination with older_id
      if older_id
        path += "?older_id=#{older_id}"
      end

      get(path)
    end

    def start_session!
      response = post("/v1/session-server",
        { secret: @credentials[:api_key] },
        auth_token: @credentials[:installation_token],
        sign: true)

      @session_token = response.dig("Response", 1, "Token", "token")

      unless @session_token
        raise AuthenticationError, "Failed to start bunq session"
      end
    end

    def user_id
      @credentials.fetch(:user_id)
    end

    def monetary_account_id
      @credentials.fetch(:monetary_account_id)
    end

    def private_key
      @private_key ||= OpenSSL::PKey::RSA.new(@credentials.fetch(:private_key))
    end

    def parse_date(datetime_string)
      return nil unless datetime_string

      # bunq returns dates like "2025-03-05 16:12:11.918100"
      DateTime.parse(datetime_string).to_date
    rescue ArgumentError
      nil
    end

    # HTTP helpers

    def http
      @http ||= begin
        http = Net::HTTP.new(@base_uri.host, @base_uri.port)
        http.use_ssl = true
        http.read_timeout = 30
        http.open_timeout = 10
        http
      end
    end

    def post(path, body, auth_token:, sign: false)
      request = Net::HTTP::Post.new(path)
      set_common_headers(request)
      request["Content-Type"] = "application/json"
      request["X-Bunq-Client-Authentication"] = auth_token if auth_token

      json_body = body.to_json
      request.body = json_body

      if sign
        signature = sign_request(json_body)
        request["X-Bunq-Client-Signature"] = signature
      end

      execute_request(request)
    end

    def get(path)
      request = Net::HTTP::Get.new(path)
      set_common_headers(request)
      request["X-Bunq-Client-Authentication"] = @session_token

      execute_request(request)
    end

    def set_common_headers(request)
      request["User-Agent"] = "CSA-Admin/1.0"
      request["Cache-Control"] = "no-cache"
      request["X-Bunq-Client-Request-Id"] = SecureRandom.uuid
    end

    def sign_request(body)
      signature = private_key.sign(OpenSSL::Digest.new("SHA256"), body)
      Base64.strict_encode64(signature)
    end

    def execute_request(request)
      response = http.request(request)
      handle_response(response)
    rescue Errno::ECONNREFUSED, Errno::ETIMEDOUT, Net::OpenTimeout, Net::ReadTimeout => e
      Rails.event.notify(:bunq_connection_error, error: e.class.name, message: e.message)
      raise MaintenanceError, "bunq API connection error: #{e.message}"
    end

    def handle_response(response)
      body = JSON.parse(response.body)
      error_msg = extract_error(body)

      case response.code.to_i
      when 200..299
        body
      when 401, 403
        raise AuthenticationError, "bunq authentication failed: #{error_msg}"
      when 500..599
        Rails.event.notify(:bunq_server_error, status: response.code, error: error_msg)
        raise MaintenanceError, "bunq API server error: #{error_msg}"
      else
        raise AuthenticationError, "bunq API error (#{response.code}): #{error_msg}"
      end
    rescue JSON::ParserError
      raise MaintenanceError, "Invalid JSON response from bunq API"
    end

    def extract_error(body)
      body.dig("Error")&.map { |e| e["error_description"] }&.join(", ") || "Unknown error"
    end
  end
end

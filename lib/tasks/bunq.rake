# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "openssl"
require "base64"

namespace :bunq do
  desc "Setup bunq API connection for a tenant (requires TENANT_NAME and BUNQ_API_KEY)"
  task setup: :environment do
    tenant = ENV.fetch("TENANT_NAME") do
      abort "ERROR: TENANT_NAME environment variable is required"
    end

    api_key = ENV.fetch("BUNQ_API_KEY") do
      abort "ERROR: BUNQ_API_KEY environment variable is required"
    end

    puts "Setting up bunq connection for tenant '#{tenant}'..."
    puts ""

    Tenant.switch(tenant) do
      org = Organization.instance
      setup = BunqSetup.new(org, api_key:)
      setup.run!
    end

    puts ""
    puts "bunq setup completed successfully for tenant '#{tenant}'!"
  end

  # Helper class to encapsulate the bunq setup logic.
  # Persists credentials incrementally to bank_credentials to avoid losing
  # progress if an error occurs mid-setup.
  class BunqSetup
    DESCRIPTION = "CSA Admin"
    API_URL = "https://api.bunq.com"

    def initialize(org, api_key:)
      @org = org
      @api_key = api_key
      @base_uri = URI(API_URL)
      @http = nil
      @session_token = nil
    end

    def run!
      generate_keypair
      create_installation
      register_device
      start_session
      fetch_monetary_accounts
      finalize
    end

    private

    def credentials
      @org.bank_credentials.symbolize_keys
    end

    def update_credentials!(new_values)
      @org.update!(bank_credentials: credentials.merge(new_values))
    end

    # Step 1: Generate RSA keypair and store API key
    def generate_keypair
      puts "1. Generating RSA keypair..."

      # Don't regenerate keypair if installation already exists (signature would mismatch)
      if credentials[:private_key].present? && credentials[:installation_token].present?
        # Just ensure api_key is stored
        update_credentials!(api_key: @api_key) unless credentials[:api_key].present?
        puts "   Using existing keypair from bank_credentials"
        return
      end

      keypair = OpenSSL::PKey::RSA.new(2048)
      update_credentials!(private_key: keypair.to_pem, api_key: @api_key)

      puts "   Keypair generated and saved"
    end

    # Step 2: Create installation with public key
    def create_installation
      puts "2. Creating bunq installation..."

      if credentials[:installation_token].present? && credentials[:server_public_key].present?
        puts "   Using existing installation from bank_credentials"
        return
      end

      public_key = OpenSSL::PKey::RSA.new(credentials[:private_key]).public_key.to_pem

      response = post("/v1/installation",
        { client_public_key: public_key },
        auth_token: nil,
        sign: false)

      installation_id = response.dig("Response", 0, "Id", "id")
      installation_token = response.dig("Response", 1, "Token", "token")
      server_public_key = response.dig("Response", 2, "ServerPublicKey", "server_public_key")

      unless installation_id && installation_token && server_public_key
        raise "Failed to parse installation response: #{response.inspect}"
      end

      update_credentials!(
        installation_id: installation_id,
        installation_token: installation_token,
        server_public_key: server_public_key
      )

      puts "   Installation created (ID: #{installation_id})"
    end

    # Step 3: Register device with API key
    def register_device
      puts "3. Registering device..."

      if credentials[:device_id].present?
        puts "   Using existing device from bank_credentials"
        return
      end

      # Use wildcard IP to allow calls from any IP
      response = post("/v1/device-server",
        {
          description: DESCRIPTION,
          secret: @api_key,
          permitted_ips: [ "*" ]
        },
        auth_token: credentials[:installation_token],
        sign: false)

      device_id = response.dig("Response", 0, "Id", "id")

      unless device_id
        raise "Failed to parse device-server response: #{response.inspect}"
      end

      update_credentials!(device_id: device_id)

      puts "   Device registered (ID: #{device_id})"
    end

    # Step 4: Start session to get user ID (session token kept in memory only)
    def start_session
      puts "4. Starting session..."

      response = post("/v1/session-server",
        { secret: @api_key },
        auth_token: credentials[:installation_token],
        sign: true)

      @session_token = response.dig("Response", 1, "Token", "token")

      # User can be UserPerson, UserCompany, or UserApiKey
      user_data = response["Response"].find { |r|
        r.key?("UserPerson") || r.key?("UserCompany") || r.key?("UserApiKey")
      }

      user_type = user_data&.keys&.first
      user_id = user_data&.dig(user_type, "id")

      unless @session_token && user_id
        raise "Failed to parse session-server response: #{response.inspect}"
      end

      # Only persist user_id, session is temporary
      update_credentials!(user_id: user_id)

      puts "   Session started (User ID: #{user_id}, Type: #{user_type})"
    end

    # Step 5: Fetch monetary accounts and let user choose or auto-select
    def fetch_monetary_accounts
      puts "5. Fetching monetary accounts..."

      if credentials[:monetary_account_id].present?
        puts "   Using existing monetary account from bank_credentials (ID: #{credentials[:monetary_account_id]})"
        return
      end

      response = get("/v1/user/#{credentials[:user_id]}/monetary-account",
        auth_token: @session_token)

      accounts = response["Response"].filter_map { |r|
        account = r.values.first
        next unless account && account["status"] == "ACTIVE"

        iban = account.dig("alias")&.find { |a| a["type"] == "IBAN" }&.dig("value")
        {
          id: account["id"],
          description: account["description"],
          iban: iban,
          currency: account.dig("currency"),
          balance: account.dig("balance", "value")
        }
      }

      if accounts.empty?
        puts "   WARNING: No active monetary accounts found!"
        return
      end

      puts "   Found #{accounts.size} active account(s):"
      accounts.each_with_index do |account, i|
        puts "   #{i + 1}. #{account[:description]} (#{account[:iban]}) - #{account[:currency]} #{account[:balance]}"
      end

      # Auto-select if only one account, otherwise use first one
      # In production, this could be interactive or based on IBAN matching
      selected = if accounts.size == 1
        accounts.first
      else
        # Try to match with org's IBAN
        matched = accounts.find { |a| a[:iban] == @org.iban }
        matched || accounts.first
      end

      update_credentials!(
        monetary_account_id: selected[:id],
        monetary_account_iban: selected[:iban]
      )

      puts "   Selected account: #{selected[:description]} (#{selected[:iban]})"
    end

    # Step 6: Update bank connection type
    def finalize
      puts "6. Finalizing setup..."

      if @org.bank_connection_type == "bunq"
        puts "   Bank connection type already set to 'bunq'"
        return
      end

      @org.update!(bank_connection_type: "bunq")

      puts "   Bank connection type set to 'bunq'"
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
      request["Content-Type"] = "application/json"
      request["User-Agent"] = "CSA-Admin/1.0"
      request["Cache-Control"] = "no-cache"
      request["X-Bunq-Client-Request-Id"] = SecureRandom.uuid

      if auth_token
        request["X-Bunq-Client-Authentication"] = auth_token
      end

      json_body = body.to_json
      request.body = json_body

      if sign
        signature = sign_request(json_body)
        request["X-Bunq-Client-Signature"] = signature
      end

      response = http.request(request)
      handle_response(response)
    end

    def get(path, auth_token:)
      request = Net::HTTP::Get.new(path)
      request["User-Agent"] = "CSA-Admin/1.0"
      request["Cache-Control"] = "no-cache"
      request["X-Bunq-Client-Request-Id"] = SecureRandom.uuid
      request["X-Bunq-Client-Authentication"] = auth_token

      response = http.request(request)
      handle_response(response)
    end

    def sign_request(body)
      private_key = OpenSSL::PKey::RSA.new(credentials[:private_key])
      signature = private_key.sign(OpenSSL::Digest.new("SHA256"), body)
      Base64.strict_encode64(signature)
    end

    def handle_response(response)
      body = JSON.parse(response.body)

      unless response.code.to_i.in?(200..299)
        error_messages = body.dig("Error")&.map { |e| e["error_description"] }&.join(", ")
        raise "bunq API error (#{response.code}): #{error_messages || response.body}"
      end

      body
    rescue JSON::ParserError
      raise "Invalid JSON response from bunq API: #{response.body}"
    end
  end
end

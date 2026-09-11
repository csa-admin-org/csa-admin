# frozen_string_literal: true

module Query
  module TestHelper
    def query_token(tenants: "*")
      Query::Token.new(name: "test-bot", secret: "query-secret", tenants: tenants)
    end

    def with_query_token(token = query_token)
      Query::Token.stub(:entries, [ token ]) { yield token }
    end

    def query_get(path, token: nil, params: {})
      query_request(:get, path, token: token, params: params)
    end

    def query_post(path, token: nil, params: {})
      query_request(:post, path, token: token, params: params)
    end

    def query_request(method, path, token: nil, params: {})
      previous = Tenant.current
      Tenant.disconnect
      with_env("APP_DOMAIN" => "acme.test") do
        with_query_token do |default_token|
          secret = token || default_token.secret
          authorization = ActionController::HttpAuthentication::Token.encode_credentials(secret)
          host! "query.acme.test"
          headers = {
            "ACCEPT" => "application/json",
            "AUTHORIZATION" => authorization
          }
          if method == :post
            post path, params: params, headers: headers, as: :json
          else
            get path, params: params, headers: headers
          end
        end
      end
    ensure
      Tenant.connect(previous) if previous
    end
  end
end

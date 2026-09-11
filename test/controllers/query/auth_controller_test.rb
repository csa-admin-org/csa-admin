# frozen_string_literal: true

require "test_helper"

class Query::AuthControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "requires token" do
    query_get "/", token: "nope"

    assert_response :unauthorized
    assert_equal "unauthorized", json_response["error"]
  end

  test "organization api_token is unauthorized" do
    query_get "/", token: Current.org.api_token

    assert_response :unauthorized
  end

  test "query token cannot use organization /api/v1" do
    with_env("APP_DOMAIN" => "acme.test") do
      with_query_token do |token|
        authorization = ActionController::HttpAuthentication::Token.encode_credentials(token.secret)
        host! "admin.acme.test"
        get "/api/v1/configuration", headers: {
          "ACCEPT" => "application/json",
          "AUTHORIZATION" => authorization
        }
      end
    end

    assert_response :unauthorized
  end
end

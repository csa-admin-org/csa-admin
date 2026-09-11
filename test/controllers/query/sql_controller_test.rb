# frozen_string_literal: true

require "test_helper"

class Query::SqlControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "runs a select" do
    query_post "/acme/sql", params: { sql: "SELECT id, name FROM members WHERE id = #{members(:john).id}" }

    assert_response :success
    assert_equal [ "id", "name" ], json_response["columns"]
    assert_equal 1, json_response["rows"].length
    assert_equal members(:john).id, json_response["rows"].first.first
    refute json_response["meta"]["has_more"]
  end

  test "select star on organizations is 400" do
    query_post "/acme/sql", params: { sql: "SELECT * FROM organizations" }

    assert_response :bad_request
    assert_match(/api_token/, json_response["error"])
  end

  test "aliased star on organizations is 400" do
    query_post "/acme/sql", params: { sql: "SELECT o.* FROM organizations o" }

    assert_response :bad_request
    assert_match(/api_token/, json_response["error"])
  end

  test "insert is 400" do
    query_post "/acme/sql", params: { sql: "INSERT INTO members (name) VALUES ('x')" }

    assert_response :bad_request
    assert_match(/forbidden/, json_response["error"])
  end

  test "unknown tenant is 404" do
    query_post "/unknown/sql", params: { sql: "SELECT 1" }

    assert_response :not_found
  end

  test "tenant not on allowlist is 404" do
    limited = query_token(tenants: [ "acme" ])
    previous = Tenant.current
    Tenant.disconnect
    with_env("APP_DOMAIN" => "acme.test") do
      Query::Token.stub(:entries, [ limited ]) do
        authorization = ActionController::HttpAuthentication::Token.encode_credentials(limited.secret)
        host! "query.acme.test"
        post "/beta/sql", params: { sql: "SELECT 1" }, headers: {
          "ACCEPT" => "application/json",
          "AUTHORIZATION" => authorization
        }, as: :json
      end
    end

    assert_response :not_found
  ensure
    Tenant.connect(previous) if previous
  end

  test "paginates" do
    query_post "/acme/sql", params: { sql: "SELECT id FROM members ORDER BY id", per: 1 }

    assert_response :success
    assert_equal 1, json_response["rows"].length
    assert json_response["meta"]["has_more"]
  end
end

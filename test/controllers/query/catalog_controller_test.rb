# frozen_string_literal: true

require "test_helper"

class Query::CatalogControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "lists query routes and wildcard tenants" do
    query_get "/"

    assert_response :success
    paths = json_response["routes"].map { |route| route["path"] }
    assert_includes paths, "/"
    assert_includes paths, "/:tenant/sql"
    assert_includes paths, "/:tenant/explain"
    assert_includes paths, "/:tenant/schema"
    assert_includes paths, "/:tenant/schema/:table"
    assert_includes paths, "/:tenant/models"
    paths.each { |path| assert_no_match(%r{\A/api/v1}, path) }
    assert_equal [ "*" ], json_response["tenants"]
  end

  test "limited token returns only those slugs" do
    limited = query_token(tenants: [ "acme" ])
    previous = Tenant.current
    Tenant.disconnect
    with_env("APP_DOMAIN" => "acme.test") do
      Query::Token.stub(:entries, [ limited ]) do
        authorization = ActionController::HttpAuthentication::Token.encode_credentials(limited.secret)
        host! "query.acme.test"
        get "/", headers: {
          "ACCEPT" => "application/json",
          "AUTHORIZATION" => authorization
        }
      end
    end

    assert_response :success
    assert_equal [ "acme" ], json_response["tenants"]
  ensure
    Tenant.connect(previous) if previous
  end

  test "defaults to json without Accept" do
    previous = Tenant.current
    Tenant.disconnect
    with_env("APP_DOMAIN" => "acme.test") do
      with_query_token do |token|
        host! "query.acme.test"
        get "/", headers: {
          "AUTHORIZATION" => ActionController::HttpAuthentication::Token.encode_credentials(token.secret)
        }
      end
    end

    assert_response :success
    assert_equal "application/json", response.media_type
  ensure
    Tenant.connect(previous) if previous
  end
end

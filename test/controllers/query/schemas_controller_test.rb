# frozen_string_literal: true

require "test_helper"

class Query::SchemasControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "lists tables including sessions" do
    query_get "/acme/schema"

    assert_response :success
    names = json_response["rows"].flatten
    assert_includes names, "members"
    assert_includes names, "sessions"
  end

  test "table detail includes encrypted columns" do
    query_get "/acme/schema/organizations"

    assert_response :success
    names = json_response["columns"].map { |col| col["name"] }
    assert_includes names, "name"
    assert_includes names, "api_token"
    assert_includes names, "icalendar_auth_token"
  end

  test "sqlite_master is 404" do
    query_get "/acme/schema/sqlite_master"

    assert_response :not_found
  end

  test "missing table is 404" do
    query_get "/acme/schema/nope"

    assert_response :not_found
  end
end

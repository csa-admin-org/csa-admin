# frozen_string_literal: true

require "test_helper"

class Query::BankConnectionsControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "lists bank connections without credentials" do
    BankConnection.create!(
      provider: "bunq",
      name: "Main",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: { api_key: "test" })

    query_get "/bank_connections"

    assert_response :success
    row = json_response["bank_connections"].find { |item|
      item["tenant"] == "acme" && item["provider"] == "bunq"
    }
    assert row
    assert_equal "bunq", row["provider"]
    assert_equal "ready", row["state"]
    assert row["active"]
    refute row.key?("credentials")
    refute row.key?("settings")
  end

  test "filters by provider" do
    BankConnection.create!(
      provider: "bunq",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: { api_key: "test" })

    query_get "/bank_connections", params: { provider: "ebics" }

    assert_response :success
    refute json_response["bank_connections"].any? { |row|
      row["tenant"] == "acme" && row["provider"] == "bunq"
    }
  end

  test "tenant query filter does not nest a path switch" do
    BankConnection.create!(
      provider: "bunq",
      active: true,
      state: "ready",
      health_status: "healthy",
      credentials: { api_key: "test" })

    query_get "/bank_connections", params: { tenant: "acme", provider: "bunq" }

    assert_response :success
    tenants = json_response["bank_connections"].map { |row| row["tenant"] }.uniq
    assert_equal [ "acme" ], tenants
  end

  test "unknown filter is 400" do
    query_get "/bank_connections", params: { credentials: "secret" }

    assert_response :bad_request
    assert_match(/unknown filter/, json_response["error"])
  end
end

# frozen_string_literal: true

require "test_helper"

class Query::OrganizationsControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "lists live org settings" do
    query_get "/organizations"

    assert_response :success
    orgs = json_response["organizations"]
    acme = orgs.find { |row| row["tenant"] == "acme" }
    assert acme
    assert_equal "Acme", acme["name"]
    assert_includes acme["features"], "absence"
    assert_equal "provisional_absence", acme["absences_included_mode"]
    refute_includes acme.keys, "api_token"
    refute_includes acme.keys, "iban"
  end

  test "attributes selects allowlisted columns" do
    query_get "/organizations", params: { attributes: "absences_included_mode,fiscal_year_start_month" }

    assert_response :success
    acme = json_response["organizations"].find { |row| row["tenant"] == "acme" }
    assert_equal %w[tenant absences_included_mode fiscal_year_start_month], acme.keys
  end

  test "filters on an allowlisted setting" do
    org(absences_included_mode: "provisional_delivery")

    query_get "/organizations", params: { absences_included_mode: "provisional_absence" }

    assert_response :success
    tenants = json_response["organizations"].map { |row| row["tenant"] }
    refute_includes tenants, "acme"
  end

  test "features filter is membership" do
    query_get "/organizations", params: { features: "absence" }

    assert_response :success
    assert json_response["organizations"].any? { |row| row["tenant"] == "acme" }

    query_get "/organizations", params: { features: "not_a_feature" }

    assert_response :success
    refute json_response["organizations"].any? { |row| row["tenant"] == "acme" }
  end

  test "unknown attribute is 400" do
    query_get "/organizations", params: { attributes: "api_token" }

    assert_response :bad_request
    assert_match(/unknown attribute/, json_response["error"])
  end

  test "money attributes serialize as decimal strings" do
    query_get "/organizations", params: { attributes: "annual_fee", annual_fee: "30" }

    assert_response :success
    acme = json_response["organizations"].find { |row| row["tenant"] == "acme" }
    assert acme
    assert_equal "30", acme["annual_fee"]
  end

  test "tenant query filter does not nest a path switch" do
    query_get "/organizations", params: { tenant: "acme", attributes: "name" }

    assert_response :success
    tenants = json_response["organizations"].map { |row| row["tenant"] }.uniq
    assert_equal [ "acme" ], tenants
  end
end

# frozen_string_literal: true

require "test_helper"

class Query::ModelsControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "lists models including sessions" do
    query_get "/acme/models"

    assert_response :success
    tables = json_response.map { |row| row["table_name"] }
    assert_includes tables, "members"
    assert_includes tables, "sessions"
    member = json_response.find { |row| row["table_name"] == "members" }
    assert member["associations"].any?
  end
end

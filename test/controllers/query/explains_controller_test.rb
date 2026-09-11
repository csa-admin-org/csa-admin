# frozen_string_literal: true

require "test_helper"

class Query::ExplainsControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "returns query plan not bytecode" do
    query_post "/acme/explain", params: { sql: "SELECT id FROM members WHERE id = 1" }

    assert_response :success
    assert_includes json_response["columns"], "detail"
    refute_includes json_response["columns"], "opcode"
    assert json_response["rows"].any?
  end
end

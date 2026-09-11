# frozen_string_literal: true

require "test_helper"
require "query/client"

class Query::ClientTest < ActiveSupport::TestCase
  test "raises when the token env is blank" do
    error = assert_raises(Query::Client::Error) {
      Query::Client.new(token: "")
    }
    assert_equal "CSA_ADMIN_API_TOKEN is missing", error.message
  end
end

# frozen_string_literal: true

require "test_helper"

class Query::OrganizationsIndexTest < ActiveSupport::TestCase
  test "rejects encrypted columns" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: "*")

    error = assert_raises(Query::Error) {
      Query::OrganizationsIndex.run(token: token, attributes: "api_token")
    }
    assert_match "unknown attribute", error.message
  end

  test "skips custom tenants" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: "*")
    previous = Tenant.current
    Tenant.disconnect
    Tenant.stub(:custom?, -> { Tenant.current == "beta" }) do
      result = Query::OrganizationsIndex.run(token: token, attributes: "name")
      tenants = result[:organizations].map { |row| row["tenant"] }
      assert_includes tenants, "acme"
      refute_includes tenants, "beta"
    end
  ensure
    Tenant.connect(previous) if previous
  end
end

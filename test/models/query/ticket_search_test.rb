# frozen_string_literal: true

require "test_helper"

class Query::TicketSearchTest < ActiveSupport::TestCase
  test "skips custom tenants" do
    acme = Support::Ticket.create!(
      priority: :normal, subject: "Newsletter bounce", content: "Help",
      admin: admins(:external))
    with_connected_tenant("beta") do
      Support::Ticket.create!(
        priority: :normal, subject: "Newsletter bounce", content: "Beta")
    end
    token = Query::Token.new(name: "bot", secret: "s", tenants: "*")
    previous = Tenant.current
    Tenant.disconnect
    Tenant.stub(:custom?, -> { Tenant.current == "beta" }) do
      result = Query::TicketSearch.run("newsletter", token: token)
      tenants = result[:tickets].map { |ticket| ticket[:tenant] }
      assert_includes tenants, "acme"
      refute_includes tenants, "beta"
      assert_includes result[:tickets].map { |ticket| ticket[:token] }, acme.token
    end
  ensure
    Tenant.connect(previous) if previous
  end

  test "requires a query" do
    token = Query::Token.new(name: "bot", secret: "s", tenants: "*")

    error = assert_raises(Query::Error) {
      Query::TicketSearch.run(" ", token: token)
    }
    assert_equal "empty query", error.message
  end
end

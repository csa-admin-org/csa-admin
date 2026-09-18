# frozen_string_literal: true

require "test_helper"

class Query::TicketSearchesControllerTest < ActionDispatch::IntegrationTest
  include Query::TestHelper

  test "searches tickets across live tenants" do
    acme = Support::Ticket.create!(
      priority: :normal, subject: "Shop checkout", content: "Opening",
      admin: admins(:external))
    beta = nil
    with_connected_tenant("beta") do
      beta = Support::Ticket.create!(
        priority: :normal, subject: "Checkout stuck", content: "Cart is empty")
    end

    query_post "/tickets/search", params: { q: "checkout" }

    assert_response :success
    tickets = json_response["tickets"]
    tokens = tickets.map { |ticket| ticket["token"] }
    tenants = tickets.map { |ticket| ticket["tenant"] }
    assert_includes tokens, acme.token
    assert_includes tokens, beta.token
    assert_includes tenants, "acme"
    assert_includes tenants, "beta"
    hit = tickets.find { |ticket| ticket["token"] == acme.token }
    assert_equal "subject", hit["match"]
    assert_includes hit["snippet"].downcase, "checkout"
    refute json_response["meta"]["has_more"]
  end

  test "snippet is the hop that matched, emails redacted" do
    ticket = Support::Ticket.create!(
      priority: :normal, subject: "Shop checkout", content: "Opening note",
      admin: admins(:external))
    ticket.messages.create!(
      author: "support",
      body: "The cart is stuck, write to member@farm.example")

    query_post "/tickets/search", params: { q: "cart" }

    assert_response :success
    hit = json_response["tickets"].find { |row| row["token"] == ticket.token }
    assert_equal "support", hit["match"]
    assert_includes hit["snippet"], "cart is stuck"
    refute_includes hit["snippet"], "member@farm.example"
    assert_includes hit["snippet"], "[email]"
  end

  test "json tenant filters without a path switch" do
    acme = Support::Ticket.create!(
      priority: :normal, subject: "Depot hours", content: "Opening",
      admin: admins(:external))
    with_connected_tenant("beta") do
      Support::Ticket.create!(
        priority: :normal, subject: "Depot hours", content: "Beta")
    end

    query_post "/tickets/search", params: { q: "depot", tenant: "acme" }

    assert_response :success
    tenants = json_response["tickets"].map { |ticket| ticket["tenant"] }.uniq
    assert_equal [ "acme" ], tenants
    assert_includes json_response["tickets"].map { |ticket| ticket["token"] }, acme.token
  end

  test "tenant list intersects the allowlist" do
    acme = Support::Ticket.create!(
      priority: :normal, subject: "Fiscal year close", content: "When",
      admin: admins(:external))
    beta = nil
    with_connected_tenant("beta") do
      beta = Support::Ticket.create!(
        priority: :normal, subject: "Fiscal year close", content: "Beta")
    end

    query_post "/tickets/search", params: { q: "fiscal", tenant: %w[beta unknown] }

    assert_response :success
    tokens = json_response["tickets"].map { |ticket| ticket["token"] }
    assert_includes tokens, beta.token
    refute_includes tokens, acme.token
  end

  test "skips Rage de Vert test subjects" do
    ignored = Support::Ticket.create!(
      priority: :normal, subject: "Test", content: "Ignore me",
      admin: admins(:external))
    kept = Support::Ticket.create!(
      priority: :normal, subject: "Absences included", content: "How many",
      admin: admins(:external))

    query_post "/tickets/search", params: { q: "test" }

    assert_response :success
    tokens = json_response["tickets"].map { |ticket| ticket["token"] }
    refute_includes tokens, ignored.token
    assert_empty json_response["tickets"].select { |ticket| ticket["subject"].match?(/\Atest(?: \d+)?\z/i) }

    query_post "/tickets/search", params: { q: "absences" }

    assert_response :success
    assert_includes json_response["tickets"].map { |ticket| ticket["token"] }, kept.token
  end

  test "limited token only walks allowed tenants" do
    acme = Support::Ticket.create!(
      priority: :normal, subject: "Fiscal year close", content: "When",
      admin: admins(:external))
    with_connected_tenant("beta") do
      Support::Ticket.create!(
        priority: :normal, subject: "Fiscal year close", content: "Beta")
    end
    limited = query_token(tenants: [ "acme" ])
    previous = Tenant.current
    Tenant.disconnect
    with_env("APP_DOMAIN" => "acme.test") do
      Query::Token.stub(:entries, [ limited ]) do
        authorization = ActionController::HttpAuthentication::Token.encode_credentials(limited.secret)
        host! "query.acme.test"
        post "/tickets/search", params: { q: "fiscal" }, headers: {
          "ACCEPT" => "application/json",
          "AUTHORIZATION" => authorization
        }, as: :json
      end
    end

    assert_response :success
    tenants = json_response["tickets"].map { |ticket| ticket["tenant"] }.uniq
    assert_equal [ "acme" ], tenants
    assert_includes json_response["tickets"].map { |ticket| ticket["token"] }, acme.token
  ensure
    Tenant.connect(previous) if previous
  end

  test "blank q is 400" do
    query_post "/tickets/search", params: { q: "  " }

    assert_response :bad_request
    assert_equal "empty query", json_response["error"]
  end

  test "paginates with has_more" do
    Support::Ticket.create!(
      priority: :normal, subject: "First basket extra", content: "One",
      admin: admins(:external))
    Support::Ticket.create!(
      priority: :normal, subject: "Second basket extra", content: "Two",
      admin: admins(:external))

    query_post "/tickets/search", params: { q: "basket extra", per: 1 }

    assert_response :success
    assert_equal 1, json_response["tickets"].length
    assert json_response["meta"]["has_more"]
    assert_equal 1, json_response["meta"]["per_page"]
  end
end

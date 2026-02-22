# frozen_string_literal: true

require "test_helper"

class SearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "redirects to login when not authenticated" do
    get search_path(q: "dupont")

    assert_response :redirect
    assert_redirected_to login_path
  end

  test "redirects to root with search param when accessed directly" do
    login(admins(:ultra))

    get search_path(q: "john")

    assert_response :redirect
    assert_redirected_to root_path(search: "john")
  end

  test "returns results matching a member name" do
    login(admins(:ultra))
    SearchEntry.rebuild!

    get search_path(q: "john"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, "turbo-frame"
    assert_includes response.body, member_path(members(:john))
  end

  test "returns no results message for unmatched query" do
    login(admins(:ultra))
    SearchEntry.rebuild!

    get search_path(q: "zzzznotfound"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, I18n.t("search.no_results")
  end

  test "returns empty frame for short query" do
    login(admins(:ultra))

    get search_path(q: "a"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    # Short queries produce no results and no "no results" message
    assert_not_includes response.body, I18n.t("search.no_results")
  end

  test "returns empty frame for blank query" do
    login(admins(:ultra))

    get search_path(q: ""), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_not_includes response.body, I18n.t("search.no_results")
  end

  test "strips whitespace from query" do
    login(admins(:ultra))
    SearchEntry.rebuild!

    get search_path(q: "  john  "), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, member_path(members(:john))
  end

  test "renders without layout for turbo frame requests" do
    login(admins(:ultra))

    get search_path(q: "test"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    # layout: false means no full HTML document wrapper
    assert_not_includes response.body, "<!DOCTYPE"
  end

  # -- Handbook search integration --

  test "returns handbook result for a page title query" do
    login(admins(:ultra))

    get search_path(q: "billing"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:billing)
  end

  test "returns handbook result with anchor for subtitle query" do
    login(admins(:ultra))

    get search_path(q: "delivery cycles"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:deliveries, anchor: "delivery-cycles")
  end

  test "handbook results appear alongside AR record results" do
    login(admins(:ultra))
    SearchEntry.rebuild!

    # "billing" matches the handbook page AND likely some AR records (invoices, etc.)
    get search_path(q: "billing"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:billing)
  end

  test "handbook results are capped at 3" do
    login(admins(:ultra))

    # "configuration" appears as a subtitle in many handbook pages
    get search_path(q: "configuration"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    # Count occurrences of the book-open icon (used only for handbook results)
    handbook_result_count = response.body.scan("book-open").size
    assert handbook_result_count <= 3,
      "Expected at most 3 handbook results, got #{handbook_result_count}"
  end

  test "no results message shown when neither handbook nor AR match" do
    login(admins(:ultra))
    SearchEntry.rebuild!

    get search_path(q: "zzzznotfound"), headers: { "Turbo-Frame" => "search-results" }

    assert_response :success
    assert_includes response.body, I18n.t("search.no_results")
  end
end

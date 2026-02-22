# frozen_string_literal: true

require "test_helper"

class HandbookSearchControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    Handbook.clear_pages_cache!
    Handbook.clear_headings_cache!
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  # -- Authentication --

  test "redirects to login when not authenticated" do
    get handbook_search_path(q: "billing")

    assert_response :redirect
    assert_redirected_to login_path
  end

  # -- Non-Turbo-Frame guard --

  test "redirects to handbook page for non-turbo-frame requests" do
    login(admins(:ultra))

    get handbook_search_path(q: "billing", page: "deliveries")

    assert_response :redirect
    assert_redirected_to handbook_page_path(:deliveries)
  end

  test "redirects to getting_started when no page param and non-turbo-frame" do
    login(admins(:ultra))

    get handbook_search_path(q: "billing")

    assert_response :redirect
    assert_redirected_to handbook_page_path(:getting_started)
  end

  # -- Turbo Frame responses --

  test "returns turbo-frame response for valid query" do
    login(admins(:ultra))

    get handbook_search_path(q: "billing"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, "turbo-frame"
    assert_includes response.body, 'id="handbook-sidebar-results"'
  end

  test "returns results for content match" do
    login(admins(:ultra))

    # "EBICS" appears in the billing page body
    get handbook_search_path(q: "ebics"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:billing)
  end

  test "returns results with heading and page context" do
    login(admins(:ultra))

    get handbook_search_path(q: "delivery cycles"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:deliveries, anchor: "delivery-cycles", highlight: "delivery cycles")
  end

  test "returns no results message for unmatched query" do
    login(admins(:ultra))

    get handbook_search_path(q: "xyznonexistent"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, I18n.t("active_admin.shared.sidebar_section.no_handbook_results")
  end

  test "returns empty frame for short query (1 char)" do
    login(admins(:ultra))

    get handbook_search_path(q: "a"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_not_includes response.body, I18n.t("active_admin.shared.sidebar_section.no_handbook_results")
    # Should still have the turbo-frame wrapper
    assert_includes response.body, 'id="handbook-sidebar-results"'
  end

  test "returns empty frame for short query (2 chars)" do
    login(admins(:ultra))

    get handbook_search_path(q: "ab"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_not_includes response.body, I18n.t("active_admin.shared.sidebar_section.no_handbook_results")
    assert_includes response.body, 'id="handbook-sidebar-results"'
  end

  test "returns empty frame for blank query" do
    login(admins(:ultra))

    get handbook_search_path(q: ""), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_not_includes response.body, I18n.t("active_admin.shared.sidebar_section.no_handbook_results")
  end

  # -- Feature filtering --

  test "includes pages for inactive features" do
    login(admins(:ultra))

    assert_not Current.org.feature?(:bidding_round)

    get handbook_search_path(q: "bidding"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:bidding_round)
  end

  test "excludes restricted pages" do
    login(admins(:ultra))

    original = Organization::RESTRICTED_FEATURES.dup
    Organization::RESTRICTED_FEATURES.replace([ :billing ])

    get handbook_search_path(q: "billing"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    # billing page link should not appear in results
    assert_not_includes response.body, "href=\"#{handbook_page_path(:billing)}\""
  ensure
    Organization::RESTRICTED_FEATURES.replace(original)
  end

  # -- Renders without layout --

  test "renders without layout for turbo frame requests" do
    login(admins(:ultra))

    get handbook_search_path(q: "billing"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_not_includes response.body, "<!DOCTYPE"
  end

  # -- Snippet display --

  test "displays snippets in search results" do
    login(admins(:ultra))

    # "EBICS" is a distinctive term that should produce a visible snippet
    get handbook_search_path(q: "ebics"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    # The response should contain highlighted content (mark tags from highlight_search)
    assert_includes response.body, "<mark>"
  end

  # -- Highlight param --

  test "result links include highlight query param" do
    login(admins(:ultra))

    get handbook_search_path(q: "ebics"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, "highlight=ebics"
  end

  # -- Keyboard navigation attributes --

  test "result links have data-search-result attribute for keyboard navigation" do
    login(admins(:ultra))

    get handbook_search_path(q: "ebics"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, "data-search-result"
  end

  # -- Locale support --

  test "returns French results when locale is French" do
    login(admins(:ultra))
    I18n.locale = :fr

    get handbook_search_path(q: "facturation", locale: "fr"), headers: { "Turbo-Frame" => "handbook-sidebar-results" }

    assert_response :success
    assert_includes response.body, handbook_page_path(:billing)
  end
end

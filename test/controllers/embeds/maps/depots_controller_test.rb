# frozen_string_literal: true

require "test_helper"

class Embeds::Maps::DepotsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  test "returns not found when feature is disabled" do
    get "/embeds/maps/depots"

    assert_response :not_found
  end

  test "renders public depot map without authentication" do
    enable_maps
    depot = depots(:farm)
    depot.update!(
      address_name: "Farm gate",
      street: "42 Nowhere",
      zip: "1234",
      city: "Unknown",
      contact_name: "Private Contact",
      emails: "secret@example.com",
      note: "Internal note",
      price: 2,
      visible: true,
      maps_visible: true,
      latitude: 46.992979,
      longitude: 6.931932)

    get "/embeds/maps/depots"

    assert_response :success
    assert_includes response.body, "maplibre-gl"
    assert_includes response.body, "https://tiles.openfreemap.org/styles/positron"
    assert_includes response.body, "cooperativeGestures: true"
    assert_includes response.body, "AttributionControl"
    assert_includes response.body, "Our farm"
    assert_not_includes response.body, "Farm gate"
    assert_not_includes response.body, "42 Nowhere"
    assert_not_includes response.body, "Price per delivery"
    assert_no_private_depot_data
  end

  test "renders map without mapped depots" do
    enable_maps

    get "/embeds/maps/depots"

    assert_response :success
    assert_includes response.body, "maplibre-gl"
    assert_includes response.body, "const markerGroups = []"
  end

  test "excludes hidden and unmapped depots" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)
    depots(:bakery).update!(visible: false, maps_visible: true, latitude: 46.992979, longitude: 6.931932)
    depots(:home).update!(visible: true, maps_visible: false, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots"

    assert_response :success
    assert_includes response.body, "Our farm"
    assert_not_includes response.body, "Bakery"
    assert_not_includes response.body, "Home"
  end

  test "filters by requested depot ids" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)
    depots(:bakery).update!(visible: true, maps_visible: true, latitude: 46.993979, longitude: 6.932932)

    get "/embeds/maps/depots", params: { depot_ids: depots(:bakery).id }

    assert_response :success
    assert_not_includes response.body, "Our farm"
    assert_includes response.body, "Bakery"
  end

  test "depot ids filter still requires public mapped depots" do
    enable_maps
    depot = depots(:bakery)
    depot.update!(visible: false, maps_visible: true, latitude: 46.993979, longitude: 6.932932)

    get "/embeds/maps/depots", params: { depot_ids: depot.id }

    assert_response :success
    assert_includes response.body, "const markerGroups = []"
    assert_not_includes response.body, "Bakery"
  end

  test "invalid depot ids filter returns no depots" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots", params: { depot_ids: "abc,0" }

    assert_response :success
    assert_includes response.body, "const markerGroups = []"
    assert_not_includes response.body, "Our farm"
  end

  test "uses requested map style when allowed" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots", params: { style: "dark" }

    assert_response :success
    assert_includes response.body, "https://tiles.openfreemap.org/styles/dark"
  end

  test "falls back to organization map style when requested style is invalid" do
    enable_maps(style: "dark")
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots", params: { style: "javascript:alert(1)" }

    assert_response :success
    assert_includes response.body, "https://tiles.openfreemap.org/styles/dark"
    assert_not_includes response.body, "javascript:alert"
  end

  test "customizes marker color" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots", params: { marker_color: "ffffff" }

    assert_response :success
    assert_includes response.body, "const markerColor = \"#ffffff\""
    assert_includes response.body, "new maplibregl.Marker({ color: markerColor })"
  end

  test "falls back when marker color is invalid" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.992979, longitude: 6.931932)

    get "/embeds/maps/depots", params: { marker_color: "javascript:alert(1)" }

    assert_response :success
    assert_includes response.body, "const markerColor = \"#2563eb\""
    assert_not_includes response.body, "javascript:alert"
  end

  test "groups depots with very close coordinates" do
    enable_maps
    depots(:farm).update!(visible: true, maps_visible: true, latitude: 46.12341, longitude: 6.12341)
    depots(:bakery).update!(visible: true, maps_visible: true, latitude: 46.12344, longitude: 6.12344)

    get "/embeds/maps/depots"

    assert_response :success
    assert_not_includes response.body, "2 depots"
    assert_not_includes response.body, '"count":2'
    assert_includes response.body, "Our farm"
    assert_includes response.body, "Bakery"
  end

  test "allows iframe embedding from organization website origin and subdomains" do
    enable_maps

    get "/embeds/maps/depots"

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
    csp = response.headers["Content-Security-Policy"]
    assert_includes csp, "frame-ancestors 'self' https://www.acme.test https://*.acme.test"
    assert_includes csp, "https://tiles.openfreemap.org"
    assert_match %r{script-src 'self' 'nonce-[^']+' https://unpkg\.com}, csp
    assert_not_includes csp, "script-src 'self' 'unsafe-inline'"
  end

  test "allows iframe embedding from any origin in development" do
    enable_maps

    with_rails_env("development") do
      get "/embeds/maps/depots"
    end

    assert_response :success
    assert_nil response.headers["X-Frame-Options"]
    assert_includes response.headers["Content-Security-Policy"], "frame-ancestors *"
  end

  private

  def enable_maps(style: "positron")
    Current.org.update!(
      features: Current.org.features | [ :maps ],
      maps_style: style)
  end

  def assert_no_private_depot_data
    assert_not_includes response.body, "Private Contact"
    assert_not_includes response.body, "secret@example.com"
    assert_not_includes response.body, "Internal note"
  end
end

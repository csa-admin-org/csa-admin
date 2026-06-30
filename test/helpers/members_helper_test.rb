# frozen_string_literal: true

require "test_helper"

class MembersHelperTest < ActionView::TestCase
  test "deliveries_count_range_with_absences scalar: shows count with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences(26, 2)
  end

  test "deliveries_count_range_with_absences scalar: no absence annotation when zero absences" do
    assert_equal "26", deliveries_count_range_with_absences(26, 0)
  end

  test "deliveries_count_range_with_absences scalar: zero count suppresses absence annotation" do
    assert_equal "0", deliveries_count_range_with_absences(0, 2)
  end

  test "deliveries_count_range_with_absences array: single value with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences([ 26 ], [ 2 ])
  end

  test "deliveries_count_range_with_absences array: range of counts with range of absences" do
    assert_equal "24-26 (-1-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 1, 2 ])
  end

  test "deliveries_count_range_with_absences array: uniform absence shown as single value" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 2, 2 ])
  end

  test "deliveries_count_range_with_absences array: no annotation when all absences are zero" do
    assert_equal "26", deliveries_count_range_with_absences([ 26 ], [ 0 ])
  end

  test "deliveries_count_range_with_absences array: skips zero absences in mixed cycles" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 0, 2 ])
  end

  test "depot_details does not show delivery count when depot has same cycles in different order" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_all, dc_thursdays, dc_mondays ]

    assert_equal(@depots_delivery_cycles.map(&:id).sort, farm.delivery_cycle_ids.sort)
    assert_equal farm.full_address, depot_details(farm)
  end

  test "depot_details shows delivery count when depot has genuinely different cycles" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_mondays, dc_thursdays, dc_all ]

    farm.delivery_cycle_ids = [ dc_mondays.id ]

    assert_not_equal farm.full_address, depot_details(farm)
  end

  test "depot map location uses coordinates when present" do
    farm = depots(:farm)
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "46.5191,6.5668", depot_map_location(farm)
    assert_equal "https://www.google.com/maps?q=46.5191,6.5668", depot_google_maps_url(depot_map_location(farm))
  end

  test "depot map location falls back to address" do
    farm = depots(:farm)

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_location(farm)
  end

  test "depot map icon location falls back to address when maps feature is off" do
    org(features: Current.org.features - [ :maps ])
    farm = depots(:farm)

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_icon_location(farm)
  end

  test "depot map icon location uses coordinates for mapped depots when maps feature is on" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = true
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "46.5191,6.5668", depot_map_icon_location(farm)
  end

  test "depot map icon location does not fall back to address for hidden map depots" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = false
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_nil depot_map_icon_location(farm)
  end

  test "depot map icon location does not fall back to address for mapped depots without coordinates" do
    org(features: Current.org.features | [ :maps ])
    farm = depots(:farm)
    farm.maps_visible = true

    assert_nil depot_map_icon_location(farm)
  end

  test "depot map title stays human-readable when coordinates are present" do
    farm = depots(:farm)
    farm.latitude = 46.5191
    farm.longitude = 6.5668

    assert_equal "42 Nowhere, 1234 Unknown", depot_map_title(farm)
  end

  test "display_member_city_with_zip shows city and zip" do
    assert_equal "Lausanne (1000)", display_member_city_with_zip(member_address("Lausanne", "1000"))
  end

  test "display_member_city_with_zip omits missing zip" do
    assert_equal "Lausanne", display_member_city_with_zip(member_address("Lausanne", nil))
  end

  test "display_member_city_with_zip shows zip when city is missing" do
    assert_equal "1000", display_member_city_with_zip(member_address(nil, "1000"))
  end

  test "display_member_city_with_zip renders empty placeholder when city and zip are missing" do
    html = display_member_city_with_zip(member_address("", nil)).to_s

    assert_includes html, "attributes-table-empty-value"
    assert_includes html, I18n.t("active_admin.empty")
  end

  test "link_with_session renders unavailable actor as missing data" do
    html = link_with_session(Unavailable.instance, nil).to_s

    assert_includes html, Unavailable.instance.name
    assert_includes html, "muted-data"
    assert_not_includes html, "href"
  end

  private

  def member_address(city, zip)
    Struct.new(:city, :zip).new(city, zip)
  end
end

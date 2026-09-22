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

  test "members_collection pins last-used members and does not duplicate them" do
    jane = members(:jane)
    john = members(:john)
    insert_shop_order(jane, 2.days.ago)
    shop_orders(:john).update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    recent, others = members_collection(featured: Shop::Order.all_without_cart)

    assert_equal I18n.t("active_admin.searchable_select.recent"), recent.first
    assert_equal [ john.id, jane.id ], recent.last.map(&:second)
    assert recent.last.all? { |_, _, html| html.dig(:data, :recent) }
    assert_not_includes others.last.map(&:second), john.id
    assert_not_includes others.last.map(&:second), jane.id
    assert_includes others.last.map(&:second), members(:bob).id
  end

  test "members_collection caps the recent group at 8" do
    newest = Array.new(9) { |index|
      Member.create!(
        name: "Recent #{index}",
        street: "Nowhere #{index}",
        city: "City",
        zip: "1234",
        trial_baskets_count: 0)
    }
    newest.each_with_index { |member, index| insert_shop_order(member, index.hours.ago) }

    recent, others = members_collection(featured: Shop::Order.where(member: newest))

    assert_equal newest.first(8).map(&:id), recent.last.map(&:second)
    assert_includes others.last.map(&:second), newest.last.id
  end

  test "members_collection omits the recent group when there is nothing to pin" do
    collection = members_collection(featured: Shop::Order.none)

    assert_kind_of ActiveRecord::Relation, collection
    assert_equal Member.kept.order_by_name.pluck(:id), collection.pluck(:id)
  end

  test "members_collection omits the recent group when it covers the visible list" do
    john = members(:john)
    shop_orders(:john).update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    collection = members_collection(
      Shop::Order.where(member_id: john.id),
      featured: Shop::Order.all_without_cart)

    assert_kind_of ActiveRecord::Relation, collection
    assert_equal [ john.id ], collection.pluck(:id)
  end

  test "members_collection drops a discarded member from the recent group" do
    jane = members(:jane)
    john = members(:john)
    insert_shop_order(jane, 1.hour.ago)
    shop_orders(:john).update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    jane.discard

    recent, = members_collection(featured: Shop::Order.all_without_cart)

    assert_equal [ john.id ], recent.last.map(&:second)
    assert_not_includes recent.last.map(&:second), jane.id
  end

  test "members_collection still restricts options to the given relation" do
    collection = members_collection(Shop::Order.where(member_id: members(:john).id))

    assert_equal [ members(:john).id ], collection.pluck(:id)
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

  test "short_price uses two decimals for whole amounts" do
    assert_equal "30.00", short_price(30)
    assert_equal "30.00", short_price(30.0)
    assert_equal "45.50", short_price(45.5)
    assert_equal "~12.35", short_price(12.345)
  end

  test "basket_complement_details tooltips included-absence prorata" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 2)
    complement = basket_complements(:bread)
    complement.delivery_ids = cycle.current_and_future_delivery_ids.take(5)
    @depots_delivery_cycles = [ cycle ]

    html = basket_complement_details(complement).to_s
    hint = I18n.t("helpers.basket_complement_absences_included")

    assert_includes html, "title=\"#{hint}\""
    assert_not_includes basket_complement_details(complement, force_default: true).to_s, hint
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

  def insert_shop_order(member, created_at)
    Shop::Order.insert_all!([ {
      member_id: member.id,
      delivery_id: deliveries(:monday_2).id,
      delivery_type: "Delivery",
      state: "pending",
      amount: 0,
      created_at: created_at,
      updated_at: created_at
    } ])
  end
end

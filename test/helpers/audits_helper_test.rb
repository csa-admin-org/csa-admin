# frozen_string_literal: true

require "test_helper"

class AuditsHelperTest < ActionView::TestCase
  include AuditsHelper

  # Stub auto_link for belongs_to tests since it's an ActiveAdmin helper
  def auto_link(record)
    content_tag(:a, record.name, href: "#")
  end

  # should_display_audit_change? tests

  test "should_display_audit_change? returns true for normal value changes" do
    assert should_display_audit_change?("basket_quantity", 1, 2)
  end

  test "should_display_audit_change? returns true when translated hash has content" do
    assert should_display_audit_change?("names", { "fr" => "Ancien" }, { "fr" => "Nouveau" })
  end

  test "should_display_audit_change? returns false when both translated hashes are empty" do
    assert_not should_display_audit_change?("names", { "fr" => "", "en" => "" }, { "fr" => "", "en" => "" })
  end

  test "should_display_audit_change? returns false when translated hash nil to empty" do
    assert_not should_display_audit_change?("invoice_names", nil, { "fr" => "", "en" => "" })
  end

  test "should_display_audit_change? returns false when translated hash empty to nil" do
    assert_not should_display_audit_change?("public_names", { "fr" => "" }, nil)
  end

  test "should_display_audit_change? returns true when translated hash goes from empty to filled" do
    assert should_display_audit_change?("names", { "fr" => "" }, { "fr" => "Nouveau nom" })
  end

  test "should_display_audit_change? returns false when both arrays are empty" do
    assert_not should_display_audit_change?("wdays", [], [])
  end

  test "should_display_audit_change? returns true when array changes" do
    assert should_display_audit_change?("wdays", [ 1 ], [ 1, 3 ])
  end

  # display_wdays_change tests

  test "display_wdays_change returns abbreviated day names" do
    result = display_wdays_change([ 1, 3, 5 ])
    # Should use abbreviated names (Mon, Wed, Fri in English)
    assert_includes result, t("date.abbr_day_names")[1].capitalize
    assert_includes result, t("date.abbr_day_names")[3].capitalize
    assert_includes result, t("date.abbr_day_names")[5].capitalize
  end

  test "display_wdays_change returns empty value for blank array" do
    result = display_wdays_change([])
    assert_includes result, t("active_admin.empty")
  end

  # display_phones_change tests

  test "display_audit_change formats phones in human-readable format" do
    result = display_audit_change(Member, "phones", "+41791234567")
    # Should format as readable phone number, not raw E.164
    assert_not_includes result, "+41791234567"
    assert_includes result, "79" # Swiss mobile prefix should be visible
  end

  test "display_audit_change formats multiple phones" do
    result = display_audit_change(Member, "phones", "+41791234567, +41227654321")
    # Should contain both formatted numbers
    assert_includes result, "79"
    assert_includes result, "22"
  end

  # display_audit_change tests

  test "display_audit_change handles price attributes" do
    result = display_audit_change(Membership, "basket_size_price", 25.50)
    assert_includes result, "25"
  end

  test "display_audit_change handles boolean true" do
    result = display_audit_change(Membership, "renew", true)
    assert_includes result, "status-tag"
    assert_includes result, t("active_admin.status_tag.true")
  end

  test "display_audit_change handles boolean false" do
    # Note: false.blank? returns true in Rails, so false is displayed with status-tag
    # via display_default_change -> display_boolean_change
    result = display_audit_change(Membership, "renew", false)
    assert_includes result, "status-tag"
    assert_includes result, t("active_admin.status_tag.false")
  end

  test "display_audit_change handles blank value" do
    result = display_audit_change(Membership, "basket_quantity", nil)
    assert_includes result, t("active_admin.empty")
  end

  test "display_audit_change handles date attributes" do
    result = display_audit_change(Membership, "started_on", "2024-01-15")
    assert_includes result, "15"
    # Date format uses 2-digit year
    assert_includes result, "24"
  end

  test "display_audit_change handles week_numbers enum" do
    result = display_audit_change(DeliveryCycle, "week_numbers", "odd")
    assert_includes result, t("delivery_cycle.week_numbers.odd")
  end

  test "display_audit_change handles billing_year_division" do
    result = display_audit_change(Membership, "billing_year_division", 4)
    assert_includes result, t("billing.year_division.x4")
  end

  # display_translated_hash_change tests

  test "display_translated_hash_change shows single locale value without prefix" do
    result = display_translated_hash_change({ "fr" => "Valeur", "en" => "" })
    assert_includes result, "Valeur"
    assert_not_includes result, "FR:"
  end

  test "display_translated_hash_change shows multiple locales with prefixes" do
    result = display_translated_hash_change({ "fr" => "Français", "en" => "English" })
    assert_includes result, "FR:"
    assert_includes result, "EN:"
    assert_includes result, "Français"
    assert_includes result, "English"
  end

  test "display_translated_hash_change shows empty for all blank values" do
    result = display_translated_hash_change({ "fr" => "", "en" => "" })
    assert_includes result, t("active_admin.empty")
  end

  # display_country_change tests

  test "display_audit_change handles country_code with translated name" do
    result = display_audit_change(Member, "country_code", "CH")
    # Should display country name, not code
    assert_not_includes result, ">CH<"
  end

  test "display_audit_change handles unknown country_code gracefully" do
    result = display_audit_change(Member, "country_code", "XX")
    # Falls back to the code itself
    assert_includes result, "XX"
  end

  # belongs_to association tests

  test "display_audit_change handles basket_size_id" do
    basket_size = basket_sizes(:large)
    result = display_audit_change(Membership, "basket_size_id", basket_size.id)
    assert_includes result, basket_size.name
  end

  test "display_audit_change handles depot_id" do
    depot = depots(:farm)
    result = display_audit_change(Membership, "depot_id", depot.id)
    assert_includes result, depot.name
  end

  test "display_audit_change handles delivery_cycle_id" do
    cycle = delivery_cycles(:mondays)
    result = display_audit_change(Membership, "delivery_cycle_id", cycle.id)
    assert_includes result, cycle.name
  end

  test "display_audit_change handles member_id" do
    member = members(:john)
    result = display_audit_change(Membership, "member_id", member.id)
    assert_includes result, member.name
  end

  test "display_audit_change handles unknown belongs_to id" do
    result = display_audit_change(Membership, "basket_size_id", 999999)
    assert_includes result, t("active_admin.unknown")
  end

  # depot_ids tests

  test "display_audit_change handles depot_ids" do
    depot1 = depots(:farm)
    depot2 = depots(:bakery)
    result = display_audit_change(DeliveryCycle, "depot_ids", [ depot1.id, depot2.id ])
    assert_includes result, depot1.name
    assert_includes result, depot2.name
  end

  test "display_audit_change handles empty depot_ids" do
    result = display_audit_change(DeliveryCycle, "depot_ids", [])
    assert_includes result, t("active_admin.empty")
  end

  # memberships_basket_complements tests

  test "display_audit_change handles memberships_basket_complements" do
    complement = basket_complements(:eggs)
    complements = [
      { "basket_complement_id" => complement.id, "quantity" => 2, "price" => 5.0 }
    ]
    result = display_audit_change(Membership, "memberships_basket_complements", complements)
    assert_includes result, "2x"
    assert_includes result, complement.name
  end

  test "display_audit_change handles empty memberships_basket_complements" do
    result = display_audit_change(Membership, "memberships_basket_complements", [])
    assert_includes result, t("active_admin.empty")
  end

  # Additional price attributes tests

  test "display_audit_change handles annual_fee" do
    result = display_audit_change(Member, "annual_fee", 100)
    assert_includes result, "100"
  end

  test "display_audit_change handles renewal_annual_fee" do
    result = display_audit_change(Membership, "renewal_annual_fee", 50)
    assert_includes result, "50"
  end

  # Additional date attributes tests

  test "display_audit_change handles sepa_mandate_signed_on" do
    result = display_audit_change(Member, "sepa_mandate_signed_on", "2024-03-15")
    assert_includes result, "15"
    assert_includes result, "24"
  end

  # State display tests

  test "display_audit_change handles member state" do
    result = display_audit_change(Member, "state", "active")
    assert_includes result, "status-tag"
    assert_includes result, t("states.member.active")
  end

  # render_audit_diff tests

  test "render_audit_diff returns nil for non-diff attributes" do
    result = render_audit_diff("basket_quantity", 1, 2)
    assert_nil result
  end

  test "render_audit_diff handles depot_ids with added depot" do
    depot1 = depots(:farm)
    depot2 = depots(:bakery)

    before_ids = [ depot1.id ]
    after_ids = [ depot1.id, depot2.id ]

    result = render_audit_diff("depot_ids", before_ids, after_ids)

    # Should show the added depot with + prefix
    assert_includes result, "+ #{depot2.name}"
  end

  test "render_audit_diff handles depot_ids with removed depot" do
    depot1 = depots(:farm)
    depot2 = depots(:bakery)

    before_ids = [ depot1.id, depot2.id ]
    after_ids = [ depot1.id ]

    result = render_audit_diff("depot_ids", before_ids, after_ids)

    # Should show the removed depot with − prefix, grayed out
    assert_includes result, "− #{depot2.name}"
    assert_includes result, "text-gray-500"
  end

  test "render_audit_diff handles shop_open_for_depot_ids with added depot" do
    depot1 = depots(:farm)
    depot2 = depots(:bakery)

    before_ids = [ depot1.id ]
    after_ids = [ depot1.id, depot2.id ]

    result = render_audit_diff("shop_open_for_depot_ids", before_ids, after_ids)

    # Should show the added depot with + prefix
    assert_includes result, "+ #{depot2.name}"
  end

  test "render_audit_diff handles shop_open_for_depot_ids with removed depot" do
    depot1 = depots(:farm)
    depot2 = depots(:bakery)

    before_ids = [ depot1.id, depot2.id ]
    after_ids = [ depot1.id ]

    result = render_audit_diff("shop_open_for_depot_ids", before_ids, after_ids)

    # Should show the removed depot with − prefix, grayed out
    assert_includes result, "− #{depot2.name}"
    assert_includes result, "text-gray-500"
  end

  test "render_audit_diff handles wdays with changes" do
    before_wdays = [ 1, 3 ]  # Monday, Wednesday
    after_wdays = [ 1, 5 ]   # Monday, Friday

    result = render_audit_diff("wdays", before_wdays, after_wdays)

    # Should show Wednesday removed with −, Friday added with + (full day names)
    assert_includes result, "− #{t('date.day_names')[3].capitalize}"  # Wednesday removed
    assert_includes result, "+ #{t('date.day_names')[5].capitalize}"  # Friday added
  end

  test "render_audit_diff handles periods with added period" do
    before_periods = []
    after_periods = [ { "from_fy_month" => 1, "to_fy_month" => 6, "results" => "all" } ]

    result = render_audit_diff("periods", before_periods, after_periods)

    assert_includes result, t("active_admin.empty")
    assert_includes result, "→"
    assert_includes result, t("delivery_cycle.results.all")
  end

  test "render_audit_diff handles periods with removed period" do
    before_periods = [ { "from_fy_month" => 1, "to_fy_month" => 6, "results" => "all" } ]
    after_periods = []

    result = render_audit_diff("periods", before_periods, after_periods)

    assert_includes result, t("delivery_cycle.results.all")
    assert_includes result, "→"
    assert_includes result, t("active_admin.empty")
  end

  test "render_audit_diff handles periods with modified period" do
    before_periods = [ { "from_fy_month" => 1, "to_fy_month" => 12, "results" => "all" } ]
    after_periods = [ { "from_fy_month" => 1, "to_fy_month" => 12, "results" => "odd" } ]

    result = render_audit_diff("periods", before_periods, after_periods)

    assert_includes result, t("delivery_cycle.results.all")
    assert_includes result, "→"
    assert_includes result, t("delivery_cycle.results.odd")
  end

  test "render_audit_diff omits unchanged periods" do
    unchanged = { "from_fy_month" => 1, "to_fy_month" => 4, "results" => "all" }
    before_periods = [ unchanged, { "from_fy_month" => 10, "to_fy_month" => 12, "results" => "all_but_first" } ]
    after_periods = [ unchanged, { "from_fy_month" => 10, "to_fy_month" => 12, "results" => "even" } ]

    result = render_audit_diff("periods", before_periods, after_periods)

    # Should only show the changed period (Oct-Dec), not the unchanged one (Jan-Apr)
    assert_includes result, t("delivery_cycle.results.all_but_first")
    assert_includes result, t("delivery_cycle.results.even")
    # The unchanged period text should appear only once if at all - check it's not duplicated
    # Actually, it shouldn't appear at all since it's unchanged
    assert_equal 1, result.scan("→").count  # Only one change shown
  end
end

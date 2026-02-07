# frozen_string_literal: true

require "application_system_test_case"

class Members::BasketContentsDeliveriesTest < ApplicationSystemTestCase
  # Jane's baskets use depot :bakery and basket_size :large
  # Jane's first delivery is thursday_1 = 2024-04-04
  # With 12h hours_before, visible_at = 2024-04-03 12:00

  def enable_basket_content_visibility(columns = {})
    org({
      features: Current.org.features | [ :basket_content ],
      basket_content_member_visible: true,
      basket_content_member_visible_hours_before: 12,
      basket_content_member_display_quantity: true
    }.merge(columns))
  end

  def create_contents_for_thursday_1
    create_basket_content(
      delivery: deliveries(:thursday_1),
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 1,
      unit: "kg")
    create_basket_content(
      delivery: deliveries(:thursday_1),
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 3,
      unit: "pc")
  end

  test "does not show basket contents when feature is disabled" do
    travel_to "2024-04-03 13:00"
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Next"
    assert_no_text "Your basket contents"
    assert_no_text "Carrots"
    assert_no_text "Cucumbers"
  end

  test "does not show basket contents when member visibility is off" do
    travel_to "2024-04-03 13:00"
    org(features: Current.org.features | [ :basket_content ])
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Next"
    assert_no_text "Your basket contents"
    assert_no_text "Carrots"
  end

  test "does not show basket contents outside the visibility window" do
    travel_to "2024-04-01 12:00"
    enable_basket_content_visibility
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Next"
    assert_no_text "Your basket contents"
    assert_no_text "Carrots"
  end

  test "shows basket contents within the visibility window" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Your basket contents"
    assert_text "Carrots"
    assert_text "Cucumbers"
  end

  test "shows quantities when display_quantity is enabled" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility(basket_content_member_display_quantity: true)
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Carrots (1.0kg)"
    assert_text "Cucumbers (3pc)"
  end

  test "hides quantities when display_quantity is disabled" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility(basket_content_member_display_quantity: false)
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Carrots"
    assert_text "Cucumbers"
    assert_no_text "kg"
    assert_no_text "pc"
  end

  test "shows note when present" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility
    org(basket_content_member_notes: { "en" => "No guarantee, last-minute changes are possible" })
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Your basket contents"
    assert_text "No guarantee, last-minute changes are possible"
  end

  test "does not show note when blank" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility
    org(basket_content_member_notes: { "en" => "" })
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "Your basket contents"
    assert_no_text "No guarantee"
  end

  test "shows custom title" do
    travel_to "2024-04-03 13:00"
    enable_basket_content_visibility
    org(basket_content_member_titles: { "en" => "What's in your basket" })
    create_contents_for_thursday_1

    login(members(:jane))
    visit "/deliveries"

    assert_text "What's in your basket"
  end
end

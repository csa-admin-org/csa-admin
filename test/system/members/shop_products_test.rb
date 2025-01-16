# frozen_string_literal: true

require "application_system_test_case"

class Members::ShopProductsTest < ApplicationSystemTestCase
  test "shop delivery for next delivery" do
    travel_to "2024-04-01"
    login(members(:jane))
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))

    visit "/shop"
    assert_equal "/shop", current_path

    assert_text "Delivery of Thursday 4 April 202"
    assert_text "Your order can be placed or modified until Tuesday 2 April 2024, 12:00."
  end

  test "shop delivery for next delivery of member with a shop depot" do
    travel_to "2024-04-01"
    member = members(:martha)
    login(member)

    deliveries(:monday_1).update!(shop_open: true, shop_open_for_depot_ids: [ home_id ])
    deliveries(:thursday_1).update!(shop_open: true, shop_open_for_depot_ids: [ farm_id ])
    member.update!(shop_depot_id: farm_id)

    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "Delivery of Thursday 4 April 2024"
  end

  test "shop delivery for next delivery of member with a shop depot (match depot / cycle)" do
    travel_to "2024-04-01"
    member = members(:martha)
    login(member)

    delivery_cycles(:all).update!(depots: [ depots(:home) ])
    delivery_cycles(:mondays).update!(depots: [ depots(:home) ])
    delivery_cycles(:thursdays).update!(depots: [ depots(:farm) ])
    member.update!(shop_depot_id: farm_id)

    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "Delivery of Thursday 4 April 2024"
  end

  test "shop delivery open/closed depending date" do
    travel_to "2024-04-02 12:00:00"
    login(members(:jane))
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))

    travel_to "2024-04-02 12:00:00"
    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "Your order can be placed or modified until Tuesday 2 April 2024, 12:00."

    travel_to "2024-04-02 12:00:01"
    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "It is no longer possible to place an order for this delivery."
    assert_link "Delivery on Thursday 11 April 2024", href: "/shop/next"
  end

  test "shop delivery open/closed depending date and depot" do
    travel_to "2024-04-01"
    login(members(:jane))
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))

    deliveries(:thursday_1).update!(shop_open: true, shop_open_for_depot_ids: [ home_id ])
    deliveries(:thursday_2).update!(shop_open: true, shop_open_for_depot_ids: [ bakery_id ])
    deliveries(:thursday_3).update!(shop_open: true, shop_open_for_depot_ids: [ home_id ])
    deliveries(:thursday_4).update!(shop_open: true, shop_open_for_depot_ids: [ bakery_id ])

    travel_to "2024-04-09 12:00:00"
    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "Shop\n⤷ 11 April 2024"
    assert_text "Delivery of Thursday 11 April 2024"
    assert_text "Your order can be placed or modified until Tuesday 9 April 2024, 12:00"

    travel_to "2024-04-09 12:00:01"
    visit "/shop"
    assert_equal "/shop", current_path
    assert_text "Shop\n⤷ 11 April 2024"
    assert_text "It is no longer possible to place an order for this delivery."
    assert_link "Delivery on Thursday 25 April 2024", href: "/shop/next"
  end

  test "add product to cart" do
    travel_to "2024-04-01"
    member = members(:jane)
    login(member)

    variant1 = shop_product_variants(:flour_buckwheat)
    variant1.update!(available: false)
    variant2 = shop_product_variants(:oil_500)
    variant2.update!(stock: 3)
    variant3 = shop_product_variants(:bread_500)

    visit "/shop"

    assert_no_selector "#product_variant_#{variant1.id}"
    assert_selector "#product_variant_#{variant2.id}"
    assert_text "Oil\nOlive 500ml"
    within("#product_variant_#{variant2.id}") do
      assert_text "3 available"
      click_button "Add to basket"
      assert_text "2 available"
      click_button "Add to basket"
      assert_text "1 available"
      click_button "Add to basket"
      assert_text "0 available"
      assert_no_button "Add to basket"
    end
    within("#product_variant_#{variant3.id}") do
      click_button "Add to basket"
    end

    within("#cart") do
      assert_text "4 Products\nCHF 23.00"
    end

    order = member.shop_orders.last
    assert_equal 4, order.items.sum(:quantity)
    assert_equal 23, order.amount
  end

  test "shop special delivery" do
    travel_to "2024-04-01"
    member = members(:jane)
    login(member)

    Delivery.update_all(shop_open: false)

    variant1 = shop_product_variants(:flour_buckwheat)
    variant1.update!(available: false)
    variant2 = shop_product_variants(:oil_500)
    variant2.update!(stock: 3)
    variant3 = shop_product_variants(:bread_500)

    visit "/shop"
    assert_not_equal "/shop", current_path

    assert_text "Shop\n⤷ 5 April 2024"
    click_link "⤷ 5 April 2024"

    assert_equal "/shop/special/2024-04-05", current_path
    assert_text "Special delivery of Friday 5 April 2024"

    assert_no_selector "#product_variant_#{variant1.id}"
    assert_selector "#product_variant_#{variant2.id}"
    assert_no_selector "#product_variant_#{variant3.id}"

    within("#product_variant_#{variant2.id}") do
      assert_text "3 available"
      click_button "Add to basket"
      assert_text "2 available"
    end

    within("#cart") do
      assert_text "1 Product\nCHF 6.00"
    end
  end

  test "shop special delivery with custom title" do
    travel_to "2024-04-01"
    member = members(:jane)
    login(member)

    shop_special_deliveries(:wednesday).update!(title: "Super Special Delivery")

    visit "/shop/special/2024-04-05"
    assert_text "Super Special Delivery of Friday 5 April 2024"
  end
end

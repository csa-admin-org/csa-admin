# frozen_string_literal: true

require "application_system_test_case"

class Members::ShopTest < ApplicationSystemTestCase
  setup do
    login(members(:jane))
  end

  test "no shop delivery" do
    travel_to "2024-07-01"

    visit "/shop"
    assert_not_equal "/shop", current_path
  end

  test "only shop special delivery" do
    travel_to "2024-04-01"

    visit "/"
    assert_selector 'nav li[aria-label="Shop Menu"]', text: "⤷ 4 April 2024"
    assert_selector 'nav li[aria-label="Shop Menu"]', text: "⤷ 5 April 2024" # Special
  end

  test "no shop feature" do
    travel_to "2024-04-01"
    org(features: [])

    visit "/shop"
    assert_not_equal "/shop", current_path
  end

  test "menu only for session originated from admin" do
    travel_to "2024-04-01"
    org(shop_admin_only: true)

    visit "/"
    assert_no_selector 'nav li[aria-label="Shop Menu"]'

    members(:jane).sessions.last.update!(admin: admins(:master))

    visit "/"
    assert_selector 'nav li[aria-label="Shop Menu"]'
  end

  test "open to members" do
    travel_to "2024-04-01"
    deliveries(:thursday_1).update!(shop_open: false)
    deliveries(:thursday_2).update!(shop_open: true)

    visit "/"
    assert_selector 'nav li[aria-label="Shop Menu"]', text: "⤷ 11 April 2024"
  end

  test "special delivery only open to member with specific depots" do
    travel_to "2024-04-01"

    visit "/"
    assert_selector 'nav li[aria-label="Shop Menu"]', text: "⤷ 5 April 2024" # Special

    shop_special_deliveries(:wednesday).update!(available_for_depot_ids: [ home_id ])

    visit "/"
    assert_no_selector 'nav li[aria-label="Shop Menu"]', text: "⤷ 5 April 2024" # Special
  end
end

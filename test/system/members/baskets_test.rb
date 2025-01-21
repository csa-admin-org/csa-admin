# frozen_string_literal: true

require "application_system_test_case"

class Members::BasketsTest < ApplicationSystemTestCase
  test "update depot and basket complements" do
    travel_to "2024-01-01"
    org(
      membership_depot_update_allowed: true,
      membership_complements_update_allowed: true)
    membership = memberships(:jane)
    basket = membership.baskets.first

    login(members(:jane))
    assert_includes menu_nav, "Deliveries\n" + "⤷ 4 April 2024"
    click_on "Deliveries"

    assert_equal "/deliveries", current_path
    assert_text "Bakery"
    assert_text "Bread"
    assert_no_text "Eggs"

    within "#basket_#{basket.id}" do
      click_on "Edit"
    end
    choose "Home"
    fill_in "Bread", with: "2"
    fill_in "Eggs", with: "1"
    assert_no_text "Cheese"

    assert_changes -> { basket.reload.depot_id }, to: home_id do
      assert_changes -> { basket.reload.complement_ids }, to: [ eggs_id, bread_id ] do
        click_on "Confirm"
      end
    end

    assert_equal "/deliveries", current_path
    assert_text "Home"
    assert_text "2x Bread and Eggs"
  end

  test "update not allowed" do
    travel_to "2024-01-01"
    basket = memberships(:john).baskets.first

    login(members(:john))
    assert_includes menu_nav, "Deliveries\n" + "⤷ 1 April 2024"
    click_on "Deliveries"

    within "#basket_#{basket.id}" do
      assert_no_link "Edit"
    end
  end
end

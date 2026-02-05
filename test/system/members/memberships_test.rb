# frozen_string_literal: true

require "application_system_test_case"

class Members::MembershipsTest < ApplicationSystemTestCase
  setup { travel_to "2024-01-01" }

  test "active member with absence" do
    create_absence(
      started_on: "2024-04-01",
      ended_on: "2024-04-07")
    login(members(:john))

    assert_includes menu_nav, "Membership\n⤷ Current"
    click_on "Membership"

    within "#2024 ul" do
      assert_text "1 April 2024 – 3 June 202"
      assert_text "Medium basket"
      assert_text "Our farm"
      assert_text "10 Deliveries, one absence"
      assert_text "½ Days: 2 requested"
      assert_text "CHF 200.00"
    end
  end

  test "trial membership" do
    memberships(:jane).update_baskets_counts!
    login(members(:jane))

    assert_includes menu_nav, "Membership\n⤷ Trial period"
    click_on "Membership"

    within "#2024 ul" do
      assert_text "4 April 2024 – 6 June 2024"
      assert_text "Large basket"
      assert_text "Bread"
      assert_text "Bakery"
      assert_text "10 Deliveries, 2 more on trial and without commitment"
      assert_text "½ Days: 2 requested"
      assert_text "CHF 380.00"
    end
  end

  test "future membership" do
    travel_to "2023-01-01"
    login(members(:jane))

    assert_includes menu_nav, "Membership\n⤷ Future"
  end

  test "update depot" do
    org(membership_depot_update_allowed: true)
    membership = memberships(:john)
    login(members(:john))

    assert_includes menu_nav, "Membership\n⤷ Current"
    click_on "Membership"

    assert_text "Our farm"
    within "#2024" do
      click_on "Edit"
    end

    choose "Bakery"
    assert_changes -> { membership.reload.depot_id }, to: bakery_id do
      assert_changes -> { membership.next_basket.reload.depot_id }, to: bakery_id do
        click_on "Confirm"
      end
    end

    assert_equal "/memberships", current_path
    assert_text "Bakery"
  end

  test "inactive member" do
    login(members(:mary))

    assert_includes menu_nav, "½ Days\n⤷ No commitment"
    assert_includes menu_nav, "Billing\n⤷ View history"

    visit "/memberships"
    assert_equal "/activity_participations", current_path
  end
end

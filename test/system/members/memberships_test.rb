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

    assert_empty BasketOverride.where(membership: membership),
      "Membership-level depot change should not create BasketOverride records"
  end

  test "never-subscribed inactive member can open the memberships empty state" do
    login(members(:mary))

    assert_includes menu_nav, "Membership\n⤷ Subscribe?"
    click_on "Membership"

    assert_equal "/memberships", current_path
    assert_text "You don't have a membership yet."
    assert_text "Subscribe"
  end

  test "past membership shows subscribe again" do
    travel_to "2024-01-01"
    create_membership(
      member: members(:mary),
      started_on: "2023-01-01",
      ended_on: "2023-12-31")
    login(members(:mary).reload)

    assert_includes menu_nav, "Membership\n⤷ Subscribe again?"
    click_on "Membership"

    assert_text "Subscribe again"
  end

  test "membership that ended this fiscal year keeps Past and still offers subscribe again" do
    travel_to "2024-05-01"
    create_membership(
      member: members(:mary),
      started_on: "2024-01-01",
      ended_on: "2024-04-05")
    login(members(:mary).reload)

    assert_includes menu_nav, "Membership\n⤷ Past"
    click_on "Membership"

    assert_text "Subscribe again"
  end

  test "pending membership request shows a notice and no subscribe button" do
    members(:mary).update_columns(
      state: "pending",
      waiting_basket_size_id: basket_sizes(:small).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_billing_year_division: 1)
    login(members(:mary).reload)

    visit "/memberships"

    assert_includes menu_nav, "Membership"
    assert_text "Your request has been received and will be reviewed shortly."
    assert_no_text "You don't have a membership yet."
    assert_no_text "Subscribe"
  end
end

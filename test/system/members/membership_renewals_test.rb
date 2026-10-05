# frozen_string_literal: true

require "application_system_test_case"

class Members::MembershipRenewalsTest < ApplicationSystemTestCase
  setup { travel_to "2024-11-01" }

  test "renew membership" do
    membership = memberships(:jane)
    membership.touch(:renewal_opened_at)
    login(members(:jane))

    assert_includes menu_nav, "Membership\n⤷ Renewal?"

    click_on "Membership"

    choose "Renew my membership"
    click_on "Next"

    choose "Home"
    choose "Medium"
    fill_in "Bread", with: "2"
    fill_in "Eggs", with: "1"

    assert_text "Support"
    choose "+ 2.00/basket"

    choose "All" # 20 Deliveries
    choose "Monthly"

    fill_in "Note", with: "More spinach!"

    click_on "Confirm"

    assert_selector ".member-flash", text: "Your membership has been renewed. Thank you!"

    assert_includes menu_nav, "Membership\n⤷ Current"
    within "#2025 ul" do
      assert_text "7 April 2025 – 12 June 2025"
      assert_text "Medium basket"
      assert_text "2x Bread and Eggs"
      assert_text "Home"
      assert_text "20 Deliveries"
      assert_text "½ Days: 2 requested"
      assert_text "CHF 760.00"
    end

    membership.reload
    assert_equal 4, membership.billing_year_division
    assert_equal depots(:bakery), membership.depot
    assert membership.renew
    assert_nil membership.renewal_annual_fee
    assert_equal Time.current, membership.renewal_opened_at
    assert_equal Time.current, membership.renewed_at
    assert_equal "More spinach!", membership.renewal_note
    assert membership.renewed?

    renewed_membership = membership.renewed_membership
    assert_equal 12, renewed_membership.billing_year_division
    assert renewed_membership.renew
    assert_equal "2025-01-01", renewed_membership.started_on.to_s
    assert_equal "2025-12-31", renewed_membership.ended_on.to_s
    assert_equal medium_id, renewed_membership.basket_size_id
    assert_equal home_id, renewed_membership.depot_id
    assert_equal delivery_cycles(:all), renewed_membership.delivery_cycle
    assert_equal [ eggs_id, bread_id ], renewed_membership.subscribed_basket_complement_ids
  end

  test "renew a past membership but still open" do
    membership = memberships(:jane)
    membership.touch(:renewal_opened_at)

    travel_to "2025-01-05"
    login(members(:jane))

    assert_includes menu_nav, "Membership\n⤷ Renewal?"
    click_on "Membership"

    choose "Renew my membership"
    click_on "Next"

    click_on "Confirm"

    assert_selector ".member-flash", text: "Your membership has been renewed. Thank you!"

    assert_includes menu_nav, "Membership\n⤷ Current"
    within "#2025 ul" do
      assert_text "10 April 2025 – 12 June 2025"
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal "2025-01-01", renewed_membership.started_on.to_s
    assert_equal "2025-12-31", renewed_membership.ended_on.to_s
  end

  test "does not renew a past membership once the new FY has past deliveries" do
    membership = memberships(:jane)
    membership.touch(:renewal_opened_at)

    travel_to "2025-04-11"
    login(members(:jane))

    assert_not_includes menu_nav, "Renewal?"
    click_on "Membership"
    assert_no_text "Renew my membership"

    visit "membership/renew"
    assert_equal "/memberships", current_path
    assert_no_text "Renew my membership"

    assert_no_difference -> { Membership.count } do
      membership.reload
      assert membership.renewal_opened?
      assert_not membership.renewed?
      assert_nil membership.renewed_membership
    end
  end

  test "re-registration closes leftover open renewal and shows request received" do
    travel_to "2024-01-01"
    membership = create_membership(
      member: members(:mary),
      started_on: "2023-01-01",
      ended_on: "2023-12-31")
    membership.update_columns(renew: true, renewal_opened_at: Time.current)
    login(members(:mary).reload)

    visit "/new"
    fill_in "Name and surname", with: "Mary Doe"
    fill_in "Phone(s)", with: "077 142 42 42"
    check "I have read and agree to the rules."
    click_on "Submit"

    assert_equal "/memberships", current_path
    assert_text "Your request has been received and will be reviewed shortly."
    assert_no_text "Renew my membership"
    assert_not_includes menu_nav, "Renewal?"

    membership.reload
    assert membership.canceled?
    assert_not membership.renew
    assert_nil membership.renewal_opened_at
    assert_not membership.renewed?
  end

  test "renew membership with salary basket" do
    member = members(:jane)
    member.update!(salary_basket: true)
    membership = memberships(:jane)
    membership.touch(:renewal_opened_at)
    login(member)

    assert_includes menu_nav, "Membership\n⤷ Renewal?"
    click_on "Membership"

    choose "Renew my membership"
    click_on "Next"

    assert_no_text "Support"

    click_on "Confirm"

    assert_selector ".member-flash", text: "Your membership has been renewed. Thank you!"
    assert_includes menu_nav, "Membership\n⤷ Current"
    within "#2025 ul" do
      assert_text "10 April 2025 – 12 June 2025"
      assert_text "Salary baskets"
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal "2025-01-01", renewed_membership.started_on.to_s
    assert_equal "2025-12-31", renewed_membership.ended_on.to_s
    assert_equal 0, membership.price
  end

  test "cancel membership" do
    membership = memberships(:jane)
    membership.touch(:renewal_opened_at)

    login(members(:jane))

    assert_includes menu_nav, "Membership\n⤷ Renewal?"
    click_on "Membership"

    choose "Cancel my membership"
    click_on "Next"

    fill_in "Note", with: "Not enough spinach!"
    check "I support you and will continue paying the annual membership fee. CHF\u00A030"
    click_on "Confirm"

    assert_selector ".member-flash", text: "Your membership has been canceled."

    assert_includes menu_nav, "Membership\n⤷ Current"
    assert_text "Your membership has been canceled and will end after the delivery on 6 June 2024."
    membership.reload
    assert_not membership.renew
    assert_nil membership.renewal_opened_at
    assert_equal 30, membership.renewal_annual_fee
    assert_equal "Not enough spinach!", membership.renewal_note
    assert membership.canceled?
  end

  test "trying to renew a membership that is not opened for renewal" do
    login(members(:jane))
    assert_includes menu_nav, "Membership\n⤷ Current"

    visit "membership/renew"
    assert_equal 404, page.status_code
  end
end

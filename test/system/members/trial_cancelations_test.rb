# frozen_string_literal: true

require "application_system_test_case"

class Members::TrialCancelationsTest < ApplicationSystemTestCase
  setup do
    travel_to "2024-01-01"
    org(trial_baskets_count: 4)
  end

  test "cancel trial membership" do
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    assert_includes menu_nav, "Membership\n⤷ Trial period"
    click_on "Membership"

    assert_text "Trial period"
    assert_text "If you wish to cancel, your membership will end after the delivery on"

    click_on "Cancel my trial membership"

    assert_text "Trial cancelation"
    fill_in "Cancelation note(s)", with: "Not the right fit for our family"
    check "I support you and will pay the annual membership fee. CHF 30"
    click_on "Confirm cancelation"

    assert_selector ".flash", text: "Your trial membership has been canceled."

    assert_includes menu_nav, "Membership\n⤷ Trial period"
    assert_text "Your trial membership has been canceled and will end after the delivery on"

    membership.reload
    assert membership.canceled?
    assert_equal 30, membership.renewal_annual_fee
    assert_equal "Not the right fit for our family", membership.renewal_note
  end

  test "cancel trial membership without note or annual fee" do
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    click_on "Membership"
    click_on "Cancel my trial membership"

    click_on "Confirm cancelation"

    assert_selector ".flash", text: "Your trial membership has been canceled."

    membership.reload
    assert membership.canceled?
    assert_nil membership.renewal_annual_fee
    assert_equal "", membership.renewal_note
  end

  test "trial cancelation link not shown when membership is not in trial" do
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    login(member)

    click_on "Membership"

    assert_no_text "Trial period"
    assert_no_text "Cancel my trial membership"
  end

  test "trial cancelation link not shown when trial is already canceled" do
    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    membership = memberships(:jane)
    membership.update_baskets_counts!
    membership.cancel_trial!(renewal_note: "Already canceled")

    login(member)

    click_on "Membership"

    assert_no_text "Cancel my trial membership"
    assert_text "Your trial membership has been canceled and will end after the delivery on"
  end
end

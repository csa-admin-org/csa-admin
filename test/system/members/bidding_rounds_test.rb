# frozen_string_literal: true

require "application_system_test_case"

class Members::BiddingRound::PledgesTest < ApplicationSystemTestCase
  def setup
    org(features: [ "bidding_round" ])
    travel_to("2024-01-01")
  end

  test "pledge an amount" do
    member = members(:jane)

    login(member)

    assert_includes menu_nav, "Membership\n" + "⤷ Pledge your amount!"

    click_on "Pledge your amount!"

    within "#2024" do
      assert_text "CHF 380.00"
    end

    click_on "The bidding round #1 is open, make a pledge!"

    fill_in "Price per basket", with: 33.35
    click_on "Submit"

    assert_text "Your pledge has been submitted successfully!"

    within "#2024" do
      assert_text "CHF 413.50"
    end
    assert_text "Thank you for your pledge for the bidding round #1"
  end

  test "redirects when bidding_round feature is not enabled" do
    org(features: [])

    login(members(:jane))
    visit "/bidding_round/pledge"

    assert_not_equal "/bidding_round/pledge", current_path
  end

  test "redirects when none open bidding round" do
    BiddingRound.open.delete_all

    login(members(:jane))
    visit "/bidding_round/pledge"

    assert_not_equal "/bidding_round/pledge", current_path
  end
end

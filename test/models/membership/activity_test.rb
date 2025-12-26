# frozen_string_literal: true

require "test_helper"

class Membership::ActivityTest < ActiveSupport::TestCase
  test "set activity_participations_demanded_annually by default" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    membership = create_membership(basket_size: basket_sizes(:medium))

    assert_equal 5, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually using basket quantity" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    membership = create_membership(basket_size: basket_sizes(:medium), basket_quantity: 2)

    assert_equal 10, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually using basket_size and complements" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 2)
    basket_complements(:eggs).update!(activity_participations_demanded_annually: 3)

    membership = create_membership(
      basket_size: basket_sizes(:medium),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 2 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 5 + 2 * 2 + 3, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually when overridden" do
    membership = create_membership(activity_participations_demanded_annually: 12)

    assert_equal 12, membership.activity_participations_demanded_annually
  end

  test "activity_participations_missing with active membership with no activity participations" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_equal 2, membership.activity_participations_missing
  end

  test "activity_participations_missing when in trial period with deliveries count 2" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.send(:update_member_and_baskets!)

    assert membership.trial?
    assert_not membership.trial_only?
    assert_equal 0, membership.activity_participations_missing
  end

  test "activity_participations_missing when in trial period with specific dates" do
    travel_to "2024-05-01"
    member = members(:mary)
    member.update!(trial_baskets_count: 5)
    membership = create_membership(
      member: member,
      started_on: "2024-04-01",
      ended_on: "2024-04-30")

    assert_not membership.trial?
    assert membership.trial_only?
    assert_equal 0, membership.activity_participations_missing
  end

  test "set_activity_participations when activity participations are overridden" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 0,
      activity_participations_annual_price_change: 180)

    assert_equal 0, membership.activity_participations_demanded
    assert_equal 180, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations when activity participations are default" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 3)

    assert_equal 0, membership.activity_participations_demanded_diff_from_default
    assert_equal 3, membership.activity_participations_demanded
    assert_equal 0, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations when doing more than demanded" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: nil)

    assert_equal 2, membership.activity_participations_demanded_diff_from_default
    assert_equal 5, membership.activity_participations_demanded
    assert_equal(-(2 * 50), membership.activity_participations_annual_price_change)
  end

  test "set_activity_participations when doing less than demanded" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 1,
      activity_participations_annual_price_change: nil)

    assert_equal(-2, membership.activity_participations_demanded_diff_from_default)
    assert_equal 1, membership.activity_participations_demanded
    assert_equal 2 * 50, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations with a diff from default but price change overridden" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -120)

    assert_equal 2, membership.activity_participations_demanded_diff_from_default
    assert_equal 5, membership.activity_participations_demanded
    assert_equal(-120, membership.activity_participations_annual_price_change)
  end

  test "set_activity_participations when activity feature is disabled" do
    travel_to "2024-01-01"
    org(features: [])
    membership = memberships(:jane)
    membership.update!(
      activity_participations_annual_price_change: nil,
      activity_participations_demanded: nil)

    assert_equal 0, membership.activity_participations_demanded_diff_from_default
    assert_equal 0, membership.activity_participations_demanded
    assert_equal 0, membership.activity_participations_annual_price_change
  end
end

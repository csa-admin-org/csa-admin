# frozen_string_literal: true

require "test_helper"

class Membership::AbsenceTest < ActiveSupport::TestCase
  test "updates absent baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:john)

    first_basket = membership.baskets.first
    assert_equal "normal", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert second_basket.billable
  end

  test "updates trial and absent baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2, absences_billed: true)
    create_absence(
      member: members(:jane),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:jane)
    membership.reload

    first_basket = membership.baskets.first
    assert_equal "trial", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert second_basket.billable
    third_basket = membership.baskets.third
    assert_equal "trial", third_basket.state
    assert third_basket.billable
    fourth_basket = membership.baskets.fourth
    assert_equal "normal", fourth_basket.state
    assert fourth_basket.billable
  end

  test "marks absent baskets as not billable" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: false)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:john)

    first_basket = membership.baskets.first
    assert_equal "normal", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert_not second_basket.billable
  end

  test "mark last baskets are absent when all included absence aren't used yet" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-12")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3)

    assert_equal [
      [ "normal", true ],
      [ "absent", false ],
      *[ [ "normal", true ] ] * 6,
      [ "absent", false ],
      [ "absent", false ]
    ], membership.baskets.map { |b| [ b.state, b.billable ] }
  end

  test "mark last baskets are absent when all included absence aren't used yet (with basket_price_extra)" do
    travel_to "2024-01-01"
    org(features: [ :basket_price_extra, :absence ], trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-12")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3, basket_price_extra: 1)

    assert_equal [
      [ "normal", true, 1 ],
      [ "absent", false, 0 ],
      *[ [ "normal", true, 1 ] ] * 6,
      [ "absent", false, 0 ],
      [ "absent", false, 0 ]
    ], membership.baskets.map { |b| [ b.state, b.billable, b.calculated_price_extra.to_i ] }
  end

  test "mark last baskets are absent when all included absence aren't used yet with extended absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-29")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3)

    assert_equal [
      [ "normal", true ],
      [ "absent", false ],
      [ "absent", false ],
      [ "absent", false ],
      [ "absent", true ],
      *[ [ "normal", true ] ] * 5
    ], membership.baskets.map { |b| [ b.state, b.billable ] }
  end

  test "forced delivery takes priority over provisional absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    # Last 2 baskets should be provisionally absent
    assert membership.baskets[-1].absent?
    assert membership.baskets[-2].absent?
    assert_nil membership.baskets[-1].absence_id
    assert_nil membership.baskets[-2].absence_id

    # Force the last basket delivery
    ForcedDelivery.create!(basket: membership.baskets[-1])

    # Last basket should now be forced, second-to-last still absent
    assert membership.baskets[-1].reload.forced?
    assert membership.baskets[-2].reload.absent?
    assert membership.baskets[-1].billable
  end

  test "forced delivery takes priority over definitive absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: false)
    membership = memberships(:john)

    # Create an absence covering the second basket
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-12")

    second_basket = membership.baskets.second
    assert second_basket.absent?
    assert_not second_basket.billable

    # Force delivery for the absent basket
    ForcedDelivery.create!(basket: second_basket)

    # Basket should now be forced
    assert second_basket.reload.forced?
    assert second_basket.billable
  end

  test "absence clears conflicting forced deliveries" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    # Force the last basket delivery
    last_basket = membership.baskets[-1]
    ForcedDelivery.create!(basket: last_basket)
    assert last_basket.reload.forced?

    # Create an absence covering that delivery
    create_absence(
      member: members(:john),
      started_on: last_basket.delivery.date - 1.day,
      ended_on: last_basket.delivery.date + 1.day)

    # ForcedDelivery should be cleared and basket should be absent
    assert_empty membership.forced_deliveries.reload
    assert last_basket.reload.absent?
  end

  test "forced basket remains when absence is elsewhere" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    # Force the last basket delivery
    last_basket = membership.baskets[-1]
    ForcedDelivery.create!(basket: last_basket)
    assert last_basket.reload.forced?

    # Create an absence covering a different delivery
    second_basket = membership.baskets.second
    create_absence(
      member: members(:john),
      started_on: second_basket.delivery.date - 1.day,
      ended_on: second_basket.delivery.date + 1.day)

    # ForcedDelivery should still exist and basket should still be forced
    assert_equal 1, membership.forced_deliveries.reload.count
    assert last_basket.reload.forced?
    assert second_basket.reload.absent?
  end

  test "forced basket is billable" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    last_basket = membership.baskets[-1]
    assert last_basket.absent?
    assert_not last_basket.billable

    ForcedDelivery.create!(basket: last_basket)

    assert last_basket.reload.forced?
    assert last_basket.billable, "Forced basket should be billable"
  end

  test "forced delivery persists when membership baskets are recreated" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    last_basket = membership.baskets[-1]
    ForcedDelivery.create!(basket: last_basket)

    # Change something that triggers basket recreation
    membership.update!(basket_quantity: 2)

    # ForcedDelivery should still exist and basket should still be forced
    assert_equal 1, membership.forced_deliveries.count
    new_basket = membership.baskets.find_by(delivery: last_basket.delivery)
    assert new_basket.forced?
  end

  test "destroying forced delivery reverts basket to provisional absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 2)

    last_basket = membership.baskets[-1]
    fd = ForcedDelivery.create!(basket: last_basket)
    assert last_basket.reload.forced?

    fd.destroy!

    assert last_basket.reload.provisionally_absent?
  end
end

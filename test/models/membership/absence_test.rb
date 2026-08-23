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

  test "shifted definite absence does not consume an included absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true, basket_shifts_annually: 2)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)
    source = membership.baskets.second
    source_quantity = source.quantity
    create_absence(
      member: membership.member,
      started_on: source.delivery.date,
      ended_on: source.delivery.date + 1.day)
    source.reload
    target = membership.baskets.last
    target_quantity = target.quantity
    billable_quantity = membership.baskets.billable.sum(:quantity)

    assert_not source.billable?
    assert source.can_be_member_shifted?
    assert target.normal?

    source.update!(shift_target_basket_id: target.id)
    shift = source.reload.shift_as_source
    replacement = membership.baskets.provisionally_absent.sole

    assert source.absent?
    assert source.billable?
    assert_empty source
    assert_equal 0, source.quantity
    assert target.reload.normal?
    assert target.billable?
    assert target.deliverable?
    assert_equal target_quantity + source_quantity, target.quantity
    assert_not_equal target, replacement
    assert_equal membership.baskets[-2], replacement
    assert_equal billable_quantity, membership.baskets.billable.sum(:quantity)
    assert_equal 0, membership.absences_included_used
    assert_equal 1, membership.absences_included_remaining

    shift.destroy!

    assert source.reload.absent?
    assert_not source.billable?
    assert_equal source_quantity, source.quantity
    assert target.reload.normal?
    assert_equal target_quantity, target.quantity
    assert_empty membership.baskets.provisionally_absent
    assert_equal 1, membership.absences_included_used
    assert_equal 0, membership.absences_included_remaining

    membership.update!(absences_included_annually: 2)

    assert target.reload.provisionally_absent?
  end

  test "next definite absence consumes included quota after first is shifted" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true, basket_shifts_annually: 2)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)
    first_source = membership.baskets.second
    second_source = membership.baskets.third
    create_absence(
      member: membership.member,
      started_on: first_source.delivery.date,
      ended_on: second_source.delivery.date + 1.day)
    first_source.reload
    second_source.reload

    assert_not first_source.billable?
    assert second_source.billable?
    assert first_source.can_be_member_shifted?

    first_source.update!(shift_target_basket_id: membership.baskets.last.id)

    assert first_source.reload.billable?
    assert_not second_source.reload.billable?
    assert second_source.can_be_member_shifted?
    assert_equal 1, membership.absences_included_used
    assert_equal 0, membership.absences_included_remaining
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

  test "sets included absences to zero when delivery cycle has no deliveries" do
    travel_to "2024-01-01"
    org(features: [ :absence ], trial_baskets_count: 0, absences_billed: true)
    delivery = Delivery.create!(date: "2024-04-02")
    delivery_cycle = create_delivery_cycle(wdays: [ 2 ], absences_included_annually: 2)
    membership = create_membership(
      member: create_member,
      delivery_cycle: delivery_cycle,
      started_on: "2024-01-01",
      ended_on: "2024-12-31",
      absences_included_annually: 2)

    assert_equal 2, membership.reload.absences_included

    assert_nothing_raised { delivery.destroy! }

    assert_equal 0, membership.reload.absences_included
  end

  test "saves the liquid included absences on membership" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    membership.update!(absences_included_annually: 4)

    assert_equal 4, membership.reload.absences_included
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

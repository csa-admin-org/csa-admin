# frozen_string_literal: true

require "test_helper"

class Membership::TrialTest < ActiveSupport::TestCase
  # Scopes

  test "trial scope returns current memberships with remaining trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    memberships(:jane).update_baskets_counts!

    trial_memberships = Membership.trial

    assert_includes trial_memberships, memberships(:jane)
    assert_not_includes trial_memberships, memberships(:john)
  end

  test "ongoing scope returns current memberships without remaining trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    memberships(:jane).update_baskets_counts!
    memberships(:john).update_baskets_counts!

    ongoing_memberships = Membership.ongoing

    assert_includes ongoing_memberships, memberships(:john)
    assert_not_includes ongoing_memberships, memberships(:jane)
  end

  # trial?

  test "trial? returns true when remaining trial baskets exist" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert membership.trial?
  end

  test "trial? returns false when no remaining trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    membership = memberships(:john)

    assert_not membership.trial?
  end

  # trial_only?

  test "trial_only? returns true when all baskets are trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 1)
    membership = memberships(:bob)
    membership.update_baskets_counts!

    assert membership.trial_only?
  end

  test "trial_only? returns false when membership has non-trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert_not membership.trial_only?
  end

  # can_member_cancel_trial?

  test "can_member_cancel_trial? returns true for current trial membership with full trial count" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns false when org has no trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    membership = memberships(:john)

    assert_not membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns true until day before first non-trial basket" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    # Get the first non-trial basket date
    first_non_trial_basket = membership.baskets.where.not(state: :trial).order("deliveries.date").first
    assert first_non_trial_basket, "Should have non-trial baskets"

    # Day before first non-trial basket - should be able to cancel
    travel_to first_non_trial_basket.delivery.date - 1.day
    membership.update_baskets_counts!
    assert membership.can_member_cancel_trial?

    # Day of first non-trial basket - should NOT be able to cancel
    travel_to first_non_trial_basket.delivery.date
    membership.update_baskets_counts!
    assert_not membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns true when membership has only trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 1)
    membership = memberships(:bob) # Bob has only 1 basket
    membership.member.update!(trial_baskets_count: 1)
    membership.reload.update_baskets_counts!

    assert membership.trial_only?, "Membership should have only trial baskets"
    assert membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns false for past membership" do
    travel_to "2025-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)

    assert membership.past?
    assert_not membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns false when membership is already canceled" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!
    membership.update!(renew: false)

    assert membership.canceled?
    assert_not membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns false for membership not containing last trial basket (cross-membership trial)" do
    # Scenario: Member joins late in year, 4 trial baskets span two memberships
    # Current membership (starting late) has 2 trial baskets
    # Renewed membership has the remaining 2 trial baskets
    # Only the renewed membership should be cancelable
    travel_to "2024-05-20"
    org(trial_baskets_count: 4)

    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    # Shorten Jane's membership to start late, leaving only 3 deliveries
    current_membership = memberships(:jane)
    current_membership.update!(started_on: "2024-05-20", ended_on: "2024-12-31")

    # Create a renewed membership for next year (continuous)
    renewed_membership = Membership.create!(
      member: member,
      basket_size: current_membership.basket_size,
      depot: current_membership.depot,
      delivery_cycle: current_membership.delivery_cycle,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )

    member.update_trial_baskets!
    current_membership.update_baskets_counts!
    renewed_membership.update_baskets_counts!

    # Current membership should have some trial baskets
    assert current_membership.trial_baskets_count.positive?, "Current membership should have trial baskets"
    # Renewed membership should have remaining trial baskets
    assert renewed_membership.reload.trial_baskets_count.positive?, "Renewed membership should have trial baskets"

    # Current membership should NOT be cancelable (doesn't contain last trial basket)
    assert_not current_membership.can_member_cancel_trial?

    # The last trial basket should be in the renewed membership
    last_trial = member.baskets.trial.order("deliveries.date").last
    assert_equal renewed_membership.id, last_trial.membership_id

    # Renewed membership SHOULD be cancelable (contains last trial basket)
    # But it's future, not current - let's verify it's allowed
    assert renewed_membership.future?
    assert renewed_membership.can_member_cancel_trial?
  end

  test "can_member_cancel_trial? returns true for current membership containing last trial basket (cross-membership trial)" do
    # Same scenario, but now we're in 2025 and the renewed membership is current
    travel_to "2025-04-01"
    org(trial_baskets_count: 4)

    member = members(:jane)
    member.update!(trial_baskets_count: 4)
    # Set up past membership that started late in year
    past_membership = memberships(:jane)
    past_membership.update!(started_on: "2024-05-20", ended_on: "2024-12-31")

    # Create the current membership (renewed from past)
    current_membership = Membership.create!(
      member: member,
      basket_size: past_membership.basket_size,
      depot: past_membership.depot,
      delivery_cycle: past_membership.delivery_cycle,
      started_on: "2025-01-01",
      ended_on: "2025-12-31"
    )

    member.update_trial_baskets!
    current_membership.update_baskets_counts!

    assert current_membership.current?
    assert current_membership.trial?, "Current membership should be in trial"

    # This membership contains the last trial basket, so it should be cancelable
    last_trial = member.baskets.trial.order("deliveries.date").last
    assert_equal current_membership.id, last_trial.membership_id

    assert current_membership.can_member_cancel_trial?
  end

  # cancel_trial!

  test "cancel_trial! sets ended_on to last trial basket delivery date" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!
    original_ended_on = membership.ended_on

    last_trial_basket = membership.baskets.trial.order("deliveries.date").last

    membership.cancel_trial!

    assert_equal last_trial_basket.delivery.date, membership.ended_on
    assert_not_equal original_ended_on, membership.ended_on
  end

  test "cancel_trial! sets renew to false" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert membership.renew?

    membership.cancel_trial!

    assert_not membership.renew?
    assert membership.canceled?
  end

  test "cancel_trial! saves renewal_note" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    membership.cancel_trial!(renewal_note: "Not the right fit for our family")

    assert_equal "Not the right fit for our family", membership.renewal_note
  end

  test "cancel_trial! saves renewal_annual_fee when checked" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2, annual_fee: 30)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    membership.cancel_trial!(renewal_annual_fee: true)

    assert_equal 30, membership.renewal_annual_fee
  end

  test "cancel_trial! does nothing when cannot cancel trial" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    membership = memberships(:john)
    original_ended_on = membership.ended_on

    membership.cancel_trial!(renewal_note: "Should not be saved")

    assert_equal original_ended_on, membership.ended_on
    assert_nil membership.renewal_note
  end

  test "cancel_trial! removes baskets after last trial basket" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    baskets_before = membership.baskets.count
    assert baskets_before > 2

    membership.cancel_trial!

    # After cancellation, ended_on changes and baskets should be recreated
    membership.reload
    assert_equal membership.trial_baskets_count, membership.baskets.count
  end

  test "cancel_trial! notifies admins" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    membership = memberships(:jane)
    membership.update_baskets_counts!
    admins(:ultra).update!(notifications: [ "membership_trial_cancelation" ])

    assert_difference "ActionMailer::Base.deliveries.count", 1 do
      membership.cancel_trial!(renewal_note: "Not for us")
      perform_enqueued_jobs
    end
  end
end

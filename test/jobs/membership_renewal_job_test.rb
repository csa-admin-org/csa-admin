# frozen_string_literal: true

require "test_helper"

class MembershipRenewalJobTest < ActiveJob::TestCase
  def next_fy
    Current.org.next_fiscal_year
  end

  def perform(membership)
    perform_enqueued_jobs do
      MembershipRenewalJob.perform_later(membership)
    end
  end

  test "raises when no next year deliveries" do
    travel_to "2024-12-01"
    membership = memberships(:john)
    memberships(:john_future).destroy!
    Delivery.future.destroy_all
    assert_equal 0, Delivery.between(next_fy.range).count

    MembershipRenewalJob.perform_later(membership)
    assert_raise(MembershipRenewal::MissingDeliveriesError) do
      perform_enqueued_jobs
    end
  end

  test "renews a membership" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      basket_quantity: 2,
      basket_size_price: 42,
      baskets_annual_price_change: 130,
      depot_price: 3,
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -60)

    membership.basket_size.update!(price: 41)
    membership.depot.update!(price: 4)

    assert_difference "Membership.count", 1 do
      perform(membership)
    end

    new_membership = Membership.last
    assert_equal membership.member_id, new_membership.member_id
    assert_equal membership.basket_size_id, new_membership.basket_size_id
    assert_equal 41, new_membership.basket_size_price
    assert_equal 2, new_membership.basket_quantity
    assert_equal 130, new_membership.baskets_annual_price_change
    assert_equal membership.depot_id, new_membership.depot_id
    assert_equal 4, new_membership.depot_price
    assert_equal 5, new_membership.activity_participations_demanded_annually
    assert_equal(-60, new_membership.activity_participations_annual_price_change)
    assert_equal next_fy.beginning_of_year, new_membership.started_on
    assert_equal next_fy.end_of_year, new_membership.ended_on
  end
end

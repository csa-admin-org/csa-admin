# frozen_string_literal: true

require "test_helper"

class MembershipRenewalTest < ActiveSupport::TestCase
  setup { travel_to "2024-01-01" }

  test "raises when no next year deliveries" do
    travel_to "2025-01-01"
    membership = memberships(:john_future)

    assert Delivery.future_year.count.zero?
    assert_raises(MembershipRenewal::MissingDeliveriesError) do
      MembershipRenewal.new(membership).renew!
    end
  end

  test "renews a membership without complements" do
    membership = memberships(:jane)
    membership.update!(
      billing_year_division: 4,
      basket_quantity: 2,
      basket_size_price: 32,
      basket_price_extra: 1,
      baskets_annual_price_change: 130,
      depot_price: 5,
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -60)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 4, renewed_membership.billing_year_division
    assert_equal membership.member_id, renewed_membership.member_id
    assert_equal membership.basket_size_id, renewed_membership.basket_size_id
    assert_equal 2, renewed_membership.basket_quantity
    assert_equal 30, renewed_membership.basket_size_price
    assert_equal 1, renewed_membership.basket_price_extra
    assert_equal 130, renewed_membership.baskets_annual_price_change
    assert_equal membership.depot_id, renewed_membership.depot_id
    assert_equal 4, renewed_membership.depot_price
    assert_equal 5, renewed_membership.activity_participations_demanded_annually
    assert_equal(-60, renewed_membership.activity_participations_annual_price_change)
    assert_equal Current.org.next_fiscal_year.beginning_of_year, renewed_membership.started_on
    assert_equal Current.org.next_fiscal_year.end_of_year, renewed_membership.ended_on
  end

  test "with basket size change" do
    membership = memberships(:jane)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(basket_size_id: medium_id)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal medium_id, renewed_membership.basket_size_id
    assert_equal 20, renewed_membership.basket_size_price
  end

  test "renews a membership with basket_price_extra" do
    membership = memberships(:jane)
    membership.update!(basket_price_extra: 1)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(basket_price_extra: 4)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 4, renewed_membership.basket_price_extra
  end

  test "renews a membership with a new depot and delivery cycle" do
    membership = memberships(:jane)
    delivery_cycles(:mondays).update!(price: 2)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(
        depot_id: home_id,
        delivery_cycle_id: mondays_id)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal home_id, renewed_membership.depot_id
    assert_equal 9, renewed_membership.depot_price
    assert_equal mondays_id, renewed_membership.delivery_cycle_id
    assert_equal 2, renewed_membership.delivery_cycle_price
  end

  test "renew a membership with a basket size delivery cycle" do
    membership = memberships(:jane)
    basket_sizes(:large).update!(delivery_cycle: delivery_cycles(:mondays))

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(basket_size_id: large_id)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal large_id, renewed_membership.basket_size_id
    assert_equal mondays_id, renewed_membership.delivery_cycle_id
  end

  test "with complements changes" do
    membership = memberships(:jane)
    membership.update!(basket_complements_annual_price_change: 10)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(
        memberships_basket_complements_attributes: {
          "0" => { basket_complement_id: bread_id, quantity: 1 },
          "1" => { basket_complement_id: eggs_id, quantity: 1 }
        }
      )
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 0, renewed_membership.basket_complements_annual_price_change
    assert_equal 2, renewed_membership.memberships_basket_complements.count
  end

  test "with activity_participations_demanded_annually change" do
    org(activity_participations_form_max: 10, activity_price: 50)
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -100)
    assert_equal 3, membership.activity_participations_demanded_annually_by_default

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(activity_participations_demanded_annually: 6)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 3, renewed_membership.activity_participations_demanded_annually_by_default
    assert_equal 6, renewed_membership.activity_participations_demanded_annually
    assert_equal(-150, renewed_membership.activity_participations_annual_price_change)
  end

  test "with activity_participations_demanded_annually not changing" do
    org(activity_participations_form_max: 10, activity_price: 50)
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -100)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(activity_participations_demanded_annually: 5)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 5, renewed_membership.activity_participations_demanded_annually
    assert_equal(-100, renewed_membership.activity_participations_annual_price_change)
  end

  test "with billing year division change" do
    membership = memberships(:jane)

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!(billing_year_division: 1)
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 1, renewed_membership.billing_year_division
  end

  test "ignore optional attributes" do
    membership = memberships(:jane)
    membership.update!(
      baskets_annual_price_change: 130,
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -60,
      basket_complements_annual_price_change: -32)
    org(membership_renewed_attributes: %w[activity_participations_demanded_annually])

    assert_difference "Membership.count", 1 do
      MembershipRenewal.new(membership).renew!
    end

    renewed_membership = membership.reload.renewed_membership
    assert_equal 0, renewed_membership.baskets_annual_price_change
    assert_equal 5, renewed_membership.activity_participations_demanded_annually
    assert_equal 0, renewed_membership.activity_participations_annual_price_change
    assert_equal 0, renewed_membership.basket_complements_annual_price_change
  end
end

# frozen_string_literal: true

require "test_helper"

class MembershipPricingTest < ActiveSupport::TestCase
  def setup
    travel_to "2024-01-01"
  end

  def pricing(params = {})
    MembershipPricing.new(params)
  end

  test "with no params" do
    assert_equal [ 0 ], pricing.prices
  end

  test "member creation form simple pricing" do
    assert_not pricing.present?

    pricing = pricing(waiting_depot_id: farm_id)
    assert_not pricing.present?
  end

  test "member creation form with basket size and depot prices" do
    pricing = pricing(waiting_basket_size_id: small_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: medium_id)
    assert_equal [ 200, 400 ], pricing.prices

    pricing = pricing(waiting_depot_id: bakery_id)
    assert_equal [ 40, 80 ], pricing.prices

    pricing = pricing(waiting_depot_id: home_id)
    assert_equal [ 90, 180 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: small_id, waiting_depot_id: bakery_id)
    assert_equal [ 140, 280 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: small_id, waiting_depot_id: home_id)
    assert_equal [ 190, 380 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: medium_id, waiting_depot_id: home_id)
    assert_equal [ 290, 580 ], pricing.prices
  end

  test "member creation form with price_extra" do
    pricing = pricing(waiting_basket_size_id: small_id, waiting_basket_price_extra: "2")
    assert_equal [ 120, 240 ], pricing.prices
  end

  test "member creation form with multiple delivery cycles" do
    cycle = delivery_cycles(:all)
    cycle.update!(depots: [ depots(:farm) ])

    pricing = pricing(waiting_basket_size_id: small_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: small_id, waiting_depot_id: home_id)
    assert_equal [ 190 ], pricing.prices

    pricing = pricing(waiting_basket_size_id: small_id, waiting_depot_id: farm_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(
      waiting_basket_size_id: small_id,
      waiting_depot_id: farm_id,
      waiting_delivery_cycle_id: cycle.id)
    assert_equal [ 200 ], pricing.prices
  end

  test "member creation form with multiple delivery cycles price" do
    delivery_cycles(:all).update!(price: 5)

    pricing = pricing(
      waiting_basket_size_id: small_id,
      waiting_delivery_cycle_id: mondays_id)
    assert_equal [ 100 ], pricing.prices

    pricing = pricing(
      waiting_basket_size_id: small_id,
      waiting_delivery_cycle_id: all_id)
    assert_equal [ 300 ], pricing.prices
  end

  test "member creation form with multiple delivery cycles (absences included)" do
    delivery_cycles(:mondays).update!(absences_included_annually: 2)

    pricing = pricing(
      waiting_basket_size_id: small_id,
      waiting_delivery_cycle_id: thursdays_id)
    assert_equal [ 100 ], pricing.prices

    pricing = pricing(
      waiting_basket_size_id: small_id,
      waiting_delivery_cycle_id: mondays_id)
    assert_equal [ 80 ], pricing.prices
  end

  test "member creation form with multiple delivery cycles (absences included) and complements" do
    basket_complements(:eggs)
      .update!(current_deliveries: Delivery.current_year.limit(2))
    delivery_cycles(:mondays).update!(absences_included_annually: 2)

    pricing = pricing(
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 0, 60 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 60 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: mondays_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 0 ], pricing.prices
  end

  test "member creation form complements pricing" do
    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      })
    assert_equal [ 40 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 60 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "2" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 100 ], pricing.prices
  end

  test "member creation form with activity_participations_demanded_annually" do
    org(
      activity_participations_form_min: 0,
      activity_participations_form_max: 10,
      activity_price: 50)

    basket_sizes(:small).update!(activity_participations_demanded_annually: 2)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 1)

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      waiting_basket_size_id: small_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      })
    assert_equal [ 140 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      waiting_basket_size_id: small_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      waiting_activity_participations_demanded_annually: 5)
    assert_equal [ 140 - (5 - 2 - 1) * 50 ], pricing.prices

    pricing = pricing(
      waiting_delivery_cycle_id: thursdays_id,
      waiting_basket_size_id: small_id,
      members_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      waiting_activity_participations_demanded_annually: 0)
    assert_equal [ 140 + (2 + 1) * 50 ], pricing.prices
  end

  # -----------------------
  # Membership renewal form
  # -----------------------

  test "membership renewal form simple pricing" do
    assert_not pricing.present?

    pricing = pricing(depot_id: farm_id)
    assert_not pricing.present?
  end

  test "membership renewal form with basket size and depot prices" do
    pricing = pricing(basket_size_id: small_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(basket_size_id: medium_id)
    assert_equal [ 200, 400 ], pricing.prices

    pricing = pricing(depot_id: bakery_id)
    assert_equal [ 40, 80 ], pricing.prices

    pricing = pricing(depot_id: home_id)
    assert_equal [ 90, 180 ], pricing.prices

    pricing = pricing(basket_size_id: small_id, depot_id: bakery_id)
    assert_equal [ 140, 280 ], pricing.prices

    pricing = pricing(basket_size_id: small_id, depot_id: home_id)
    assert_equal [ 190, 380 ], pricing.prices

    pricing = pricing(basket_size_id: medium_id, depot_id: home_id)
    assert_equal [ 290, 580 ], pricing.prices
  end

  test "membership renewal form with price_extra" do
    pricing = pricing(basket_size_id: small_id, basket_price_extra: "2")
    assert_equal [ 120, 240 ], pricing.prices
  end

  test "membership renewal form with multiple delivery cycles" do
    cycle = delivery_cycles(:all)
    cycle.update!(depots: [ depots(:farm) ])

    pricing = pricing(basket_size_id: small_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(basket_size_id: small_id, depot_id: home_id)
    assert_equal [ 190 ], pricing.prices

    pricing = pricing(basket_size_id: small_id, depot_id: farm_id)
    assert_equal [ 100, 200 ], pricing.prices

    pricing = pricing(
      basket_size_id: small_id,
      depot_id: farm_id,
      delivery_cycle_id: cycle.id)
    assert_equal [ 200 ], pricing.prices
  end

  test "membership renewal form with multiple delivery cycles price" do
    delivery_cycles(:all).update!(price: 5)

    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: mondays_id)
    assert_equal [ 100 ], pricing.prices

    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: all_id)
    assert_equal [ 300 ], pricing.prices
  end

  test "membership renewal form with multiple delivery cycles (absences included)" do
    delivery_cycles(:mondays).update!(absences_included_annually: 2)

    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: thursdays_id)
    assert_equal [ 100 ], pricing.prices

    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: mondays_id)
    assert_equal [ 80 ], pricing.prices
  end

  test "membership renewal form with multiple delivery cycles (absences included) and complements" do
    basket_complements(:eggs)
      .update!(current_deliveries: Delivery.current_year.limit(2))
    delivery_cycles(:mondays).update!(absences_included_annually: 2)

    pricing = pricing(
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 0, 60 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 60 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: mondays_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 0 ], pricing.prices
  end

  test "membership renewal form complements pricing" do
    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      })
    assert_equal [ 40 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 60 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "2" => { basket_complement_id: eggs_id, quantity: 1 }
      })
    assert_equal [ 100 ], pricing.prices
  end

  test "membership renewal form with activity_participations_demanded_annually" do
    org(
      activity_participations_form_min: 0,
      activity_participations_form_max: 10,
      activity_price: 50)

    basket_sizes(:small).update!(activity_participations_demanded_annually: 2)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 1)

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      basket_size_id: small_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      })
    assert_equal [ 140 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      basket_size_id: small_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      activity_participations_demanded_annually: 5)
    assert_equal [ 140 - (5 - 2 - 1) * 50 ], pricing.prices

    pricing = pricing(
      delivery_cycle_id: thursdays_id,
      basket_size_id: small_id,
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      activity_participations_demanded_annually: 0)
    assert_equal [ 140 + (2 + 1) * 50 ], pricing.prices
  end

  test "basket size with availability restrictions reduces deliveries count" do
    # Small basket is 10 price, mondays has 10 deliveries = 100
    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: mondays_id)
    assert_equal [ 100 ], pricing.prices

    # Restrict basket size to only part of the year
    # Monday deliveries are from week 14 onwards (April 1 = week 14)
    # Setting first_cweek to 20 should exclude some deliveries
    basket_sizes(:small).update!(first_cweek: 20)

    pricing = pricing(
      basket_size_id: small_id,
      delivery_cycle_id: mondays_id)

    # Should be less than 100 since some deliveries are excluded
    assert pricing.prices.first < 100
  end

  test "basket size with availability restrictions affects depot and cycle pricing too" do
    depots(:bakery).update!(price: 4)

    # Without restrictions: 10 deliveries * (10 basket + 4 depot) = 140
    pricing = pricing(
      basket_size_id: small_id,
      depot_id: bakery_id,
      delivery_cycle_id: mondays_id)
    assert_equal [ 140 ], pricing.prices

    # With restrictions, both basket and depot should use reduced delivery count
    basket_sizes(:small).update!(first_cweek: 20)

    pricing = pricing(
      basket_size_id: small_id,
      depot_id: bakery_id,
      delivery_cycle_id: mondays_id)

    # Should be less than 140
    assert pricing.prices.first < 140
  end
end

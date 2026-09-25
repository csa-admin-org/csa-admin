# frozen_string_literal: true

require "test_helper"

class BiddingRound::PledgeTest < ActiveSupport::TestCase
  def setup
    travel_to("2024-01-01")
  end

  test "validates basket_size_price is greater than or equal to zero" do
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane),
      basket_size_price: -1)

    assert_not pledge.valid?
    assert_includes pledge.errors[:basket_size_price], "is invalid"
  end

  test "validates basket_size_price within allowed range" do
    org(
      bidding_round_basket_size_price_min_percentage: 50,
      bidding_round_basket_size_price_max_percentage: 50)
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane))

    pledge.basket_size_price = 14.99
    assert_not pledge.valid?
    assert_includes pledge.errors[:basket_size_price], "is invalid"

    pledge.basket_size_price = 45.01
    assert_not pledge.valid?
    assert_includes pledge.errors[:basket_size_price], "is invalid"

    # Test within range
    pledge.basket_size_price = 31
    assert pledge.valid?
  end

  test "validates bidding round must be open" do
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:draft_2024),
      membership: memberships(:jane),
      basket_size_price: 31)

    assert_not pledge.valid?
    assert_includes pledge.errors[:bidding_round], "is invalid"
  end

  test "validates membership must match bidding round fiscal year" do
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:draft_2024),
      membership: memberships(:john_future),
      basket_size_price: 32)

    assert_not pledge.valid?
    assert_includes pledge.errors[:membership], "is invalid"
  end

  test "validates one pledge per membership per bidding round" do
    BiddingRound::Pledge.create!(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane),
      basket_size_price: 31)

    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane),
      basket_size_price: 31)

    assert_not pledge.valid?
    assert_includes pledge.errors[:membership], "has already been taken"
  end

  test "default_price uses basket_size_price from previous pledge in same fiscal year" do
    previous_round = bidding_rounds(:open_2024)
    BiddingRound::Pledge.create!(
      bidding_round: previous_round,
      membership: memberships(:jane),
      basket_size_price: 42)
    previous_round.fail!

    round = bidding_rounds(:draft_2024)
    pledge = BiddingRound::Pledge.new(bidding_round: round, membership: memberships(:jane))

    assert_equal 42, pledge.basket_size_price
  end

  test "default_price falls back to membership basket_size price when no previous pledge" do
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane))

    assert_equal memberships(:jane).basket_size.price, pledge.basket_size_price
  end

  test "total_membership_baskets_price calculates correctly" do
    membership = memberships(:jane)
    membership.update!(basket_quantity: 2)
    pledge =  BiddingRound::Pledge.new(
      membership: memberships(:jane),
      basket_size_price: 31)

    assert_equal 2 * 10 * 31, pledge.total_membership_baskets_price
  end

  test "marks ten percent steps and the recommended price on the slider scale" do
    org(
      bidding_round_basket_size_price_min_percentage: 0,
      bidding_round_basket_size_price_max_percentage: 100)
    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane))

    assert_nil pledge.default_price_percentage_difference
    assert_in_delta 0.5, pledge.default_price_tick_ratio, 0.000001
    assert_equal 20, pledge.basket_size_price_tick_ratios.size
    assert_equal (0..60).step(3).map(&:to_f), pledge.basket_size_price_snap_prices
    assert_in_delta 0, pledge.basket_size_price_tick_ratios.first, 0.000001
    assert_in_delta 1, pledge.basket_size_price_tick_ratios.last, 0.000001
    assert_not pledge.basket_size_price_tick_ratios.any? { |ratio|
      (ratio - pledge.default_price_tick_ratio).abs < 0.000001
    }

    pledge.basket_size_price = 31.5
    assert_equal 5, pledge.default_price_percentage_difference

    pledge.basket_size_price = 28.5
    assert_equal(-5, pledge.default_price_percentage_difference)
  end

  test "keeps the recommended tick when it is off the ten percent steps" do
    org(
      bidding_round_basket_size_price_min_percentage: 0,
      bidding_round_basket_size_price_max_percentage: 100)
    previous_round = bidding_rounds(:open_2024)
    BiddingRound::Pledge.create!(
      bidding_round: previous_round,
      membership: memberships(:jane),
      basket_size_price: 31)
    previous_round.fail!

    pledge = BiddingRound::Pledge.new(
      bidding_round: bidding_rounds(:draft_2024),
      membership: memberships(:jane))

    assert_equal 31, pledge.default_price
    assert_nil pledge.default_price_percentage_difference
    assert_in_delta 31.0 / 60, pledge.default_price_tick_ratio, 0.000001
    assert_equal 21, pledge.basket_size_price_tick_ratios.size
    assert_includes pledge.basket_size_price_snap_prices, 31
  end

  test "price_difference_from_default calculates correctly" do
    pledge =  BiddingRound::Pledge.new(membership: memberships(:jane))

    pledge.basket_size_price = 31
    assert_equal 1, pledge.price_difference_from_default

    pledge.basket_size_price = 28
    assert_equal(-2, pledge.price_difference_from_default)
  end
end

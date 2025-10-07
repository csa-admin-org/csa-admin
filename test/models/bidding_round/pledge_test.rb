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

  test "price_difference_from_default calculates correctly" do
    pledge =  BiddingRound::Pledge.new(membership: memberships(:jane))

    pledge.basket_size_price = 31
    assert_equal 1, pledge.price_difference_from_default

    pledge.basket_size_price = 28
    assert_equal(-2, pledge.price_difference_from_default)
  end
end

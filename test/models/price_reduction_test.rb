# frozen_string_literal: true

require "test_helper"

class PriceReductionTest < ActiveSupport::TestCase
  setup { travel_to "2024-06-01" }

  test "percentage cut is of the gross and rounds to five cents" do
    reduction = price_reduction(percentage: 30)

    assert_equal 30.to_d, reduction.raw_amount(100)
    assert_equal 10.05.to_d, reduction.raw_amount(33.5)
  end

  test "fixed amount is used as the cut" do
    reduction = price_reduction(fixed_amount: 12.5, percentage: nil)

    assert_equal 12.5, reduction.raw_amount(100)
  end

  test "a cut larger than the gross clamps to it" do
    reduction = price_reduction(fixed_amount: 500, percentage: nil)

    assert_equal 80, reduction.raw_amount(80)
  end

  test "percentage and fixed amount cannot both be set" do
    reduction = PriceReduction.new(names: { "en" => "Caritas" }, percentage: 30, fixed_amount: 10)

    assert_not reduction.valid?
    assert reduction.errors.added?(:base, :percentage_xor_fixed_amount)
  end

  test "a cut that does not fit the remaining cap is not applicable" do
    reduction = price_reduction(percentage: 30, cap_amount: 20, cap_mode: "once")

    assert_not reduction.applicable_to?(100, depot: depots(:farm), year: 2024, member: members(:mary))
    assert_equal :cap, reduction.skip_reason(100, depot: depots(:farm), year: 2024, member: members(:mary))
  end

  test "a fixed amount larger than the gross is applicable when the clamped cut fits the cap" do
    reduction = price_reduction(fixed_amount: 500, percentage: nil, cap_amount: 80, cap_mode: "once")

    assert reduction.applicable_to?(80, depot: depots(:farm), year: 2024, member: members(:mary))
  end

  test "depot allow-list rejects other depots and a blank list allows all" do
    limited = price_reduction(percentage: 30, depot_ids: [ depots(:farm).id ])
    open = price_reduction(percentage: 30)

    assert limited.depot_allowed?(depots(:farm))
    assert_not limited.depot_allowed?(depots(:home))
    assert open.depot_allowed?(depots(:home))
    assert_equal :depot, limited.skip_reason(100, depot: depots(:home), year: 2024, member: members(:mary))
  end

  test "card must be present and unexpired for the date being checked" do
    card = price_reduction_card
    reduction = price_reduction(percentage: 30, price_reduction_card: card)
    member = members(:mary)
    member.member_cards.create!(price_reduction_card: card, name: "Mary", number: "1234", expires_on: Date.new(2024, 6, 1))

    assert reduction.applicable_to?(100, depot: depots(:farm), year: 2024, member: member, on: Date.new(2024, 6, 1))
    assert_not reduction.applicable_to?(100, depot: depots(:farm), year: 2024, member: member, on: Date.new(2024, 6, 2))
    assert_equal :card, reduction.skip_reason(100, depot: depots(:farm), year: 2024, member: members(:jane), on: Date.new(2024, 6, 1))
  end

  test "once cap counts every year and cannot be saved below what is already granted" do
    reduction = price_reduction(percentage: 30, cap_amount: 100, cap_mode: "once")
    grant_reduction(reduction, memberships(:jane), amount: 40)
    travel_to "2025-02-01" do
      Current.reset
      grant_reduction(reduction, memberships(:john_future), amount: 30)
      Current.reset
    end

    assert_equal 70, reduction.granted_amount
    assert_equal 30, reduction.remaining_amount

    reduction.cap_amount = 60
    assert_not reduction.valid?
    assert reduction.errors[:cap_amount].any?
  end

  test "fiscal year cap ignores past years and fails the year that is already over the new cap" do
    reduction = price_reduction(percentage: 30, cap_amount: 100, cap_mode: "fiscal_year")
    grant_reduction(reduction, memberships(:john_past), amount: 90)
    grant_reduction(reduction, memberships(:jane), amount: 40)

    assert_equal 90, reduction.granted_amount(2023)
    assert_equal 40, reduction.granted_amount(2024)
    assert_equal 60, reduction.remaining_amount(2024)

    reduction.cap_amount = 30
    assert_not reduction.valid?
    assert_match "2024", reduction.errors[:cap_amount].join

    reduction.cap_amount = 40
    assert reduction.valid?
  end

  test "discard is refused while a membership still has the grant" do
    reduction = price_reduction(percentage: 30)
    grant_reduction(reduction, memberships(:jane), amount: 10)

    assert_not reduction.can_discard?
    assert_not reduction.can_delete?
  end

  private

  def price_reduction(**attrs)
    PriceReduction.create!({
      names: { "en" => "Caritas" },
      percentage: 30
    }.merge(attrs))
  end

  def price_reduction_card
    PriceReductionCard.create!(
      names: { "en" => "CarteCulture" },
      require_name: true,
      require_number: true,
      require_expires_on: true)
  end

  def grant_reduction(reduction, membership, amount:)
    MembershipPriceReduction.create!(
      membership: membership,
      price_reduction: reduction,
      percentage: reduction.percentage,
      fixed_amount: reduction.fixed_amount,
      amount: amount)
  end
end

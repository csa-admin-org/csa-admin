# frozen_string_literal: true

require "test_helper"

class MembershipPriceReductionTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-06-01"
    org(features: Current.org.features | [ "price_reductions" ])
  end

  test "applying a reduction subtracts the cut from the membership price" do
    membership = memberships(:jane)
    before = membership.price
    reduction = price_reduction(percentage: 50)

    membership.apply_price_reduction!(reduction)
    membership.save!

    grant = membership.reload.membership_price_reduction
    assert_equal 50, grant.percentage
    assert grant.amount.positive?
    assert_equal (before - grant.amount).round(2), membership.price.to_d.round(2)
    assert_equal membership.computed_membership_price, membership.price
  end

  test "a first apply that does not fit the cap is dropped and the price stays whole" do
    membership = memberships(:jane)
    before = membership.price
    reduction = price_reduction(percentage: 50, cap_amount: 1, cap_mode: "once")

    membership.apply_price_reduction!(reduction)
    membership.save!

    assert_nil membership.reload.membership_price_reduction
    assert membership.price_reduction_skipped
    assert_equal :cap, membership.price_reduction_skip_reason
    assert_equal before, membership.price
  end

  test "an existing grant is clamped when the remaining cap shrinks, not removed" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 50, cap_amount: 1000, cap_mode: "once")
    membership.apply_price_reduction!(reduction)
    membership.save!
    granted = membership.reload.membership_price_reduction.amount

    reduction.update!(cap_amount: granted)
    membership.baskets_annual_price_change = membership.baskets_annual_price_change.to_d + 100
    membership.save!

    grant = membership.reload.membership_price_reduction
    assert grant
    assert_operator grant.amount, :<=, granted
  end

  test "editing the copied percentage fails when the new cut does not fit" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 10, cap_amount: 1000, cap_mode: "once")
    membership.apply_price_reduction!(reduction)
    membership.save!
    granted = membership.reload.membership_price_reduction.amount
    reduction.update!(cap_amount: granted)

    grant = membership.membership_price_reduction
    grant.percentage = 80
    grant.strict_cap = true

    assert_raises(ActiveRecord::RecordInvalid) { membership.save! }
    assert_equal 10, grant.reload.percentage
  end

  test "a past membership keeps the stored grant amount" do
    membership = memberships(:john_past)
    reduction = price_reduction(percentage: 50)
    MembershipPriceReduction.create!(
      membership: membership,
      price_reduction: reduction,
      percentage: 50,
      amount: 12)

    membership.update_columns(price: membership.price_before_reduction - 12)

    membership.send(:sync_price_reduction!, enforce: true)

    assert_equal 12, membership.membership_price_reduction.reload.amount
  end

  test "resubmitting the same reduction clamps a later price change instead of failing" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 50, cap_amount: 1000, cap_mode: "once")
    membership.apply_price_reduction!(reduction)
    membership.save!
    granted = membership.reload.membership_price_reduction.amount
    reduction.update!(cap_amount: granted)

    membership.price_reduction_choice_id = reduction.id
    membership.baskets_annual_price_change = membership.baskets_annual_price_change.to_d + 100
    membership.save!

    assert_operator membership.reload.membership_price_reduction.amount, :<=, granted
  end

  test "a discarded program is skipped when applied from a waiting member" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 10)
    reduction.discard!
    membership.member.update_column(:waiting_price_reduction_id, reduction.id)

    membership.apply_waiting_price_reduction!(membership.member)
    membership.save!

    assert_nil membership.reload.membership_price_reduction
    assert_equal :discarded, membership.price_reduction_skip_reason
  end

  test "a typed reduction that misses the depot fails instead of being labeled a cap error" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 10, depot_ids: [ depots(:home).id ])

    membership.price_reduction_choice_id = reduction.id

    error = assert_raises(ActiveRecord::RecordInvalid) { membership.save! }
    assert error.record.errors.added?(:price_reduction, :price_reduction_depot)
    assert_not error.record.errors.added?(:price_reduction, :price_reduction_exceeds_cap)
  end

  test "a blank nested percentage saves the catalog value and a typed value sticks" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 30)
    other = price_reduction(names: { "en" => "Other" }, percentage: nil, fixed_amount: 12)

    membership.update!(
      price_reduction_choice_id: reduction.id,
      membership_price_reduction_attributes: blank_grant_attributes)

    grant = membership.reload.membership_price_reduction
    assert_equal 30, grant.percentage
    assert_nil grant.fixed_amount

    grant.update_columns(percentage: 40)
    membership.membership_price_reduction_attributes = blank_grant_attributes(id: grant.id)
    assert membership.valid?
    assert_equal 30, membership.membership_price_reduction.percentage
    assert_not membership.membership_price_reduction.strict_cap
    membership.save!

    membership.update!(
      price_reduction_choice_id: reduction.id,
      membership_price_reduction_attributes: blank_grant_attributes(id: grant.id, percentage: "40"))

    grant.reload
    assert_equal 40, grant.percentage
    assert_nil grant.fixed_amount

    membership.update!(
      price_reduction_choice_id: other.id,
      membership_price_reduction_attributes: blank_grant_attributes(id: grant.id, fixed_amount: "9"))

    grant.reload
    assert_equal other.id, grant.price_reduction_id
    assert_nil grant.percentage
    assert_equal 9, grant.fixed_amount
  end

  test "waiting prefill skips a reduction the remaining cap cannot fund" do
    membership = memberships(:jane)
    member = membership.member
    reduction = price_reduction(percentage: 50, cap_amount: 10, cap_mode: "once")
    MembershipPriceReduction.create!(
      membership: membership,
      price_reduction: reduction,
      percentage: 50,
      amount: 10)

    member.assign_waiting_from_last_membership

    assert_nil member.waiting_price_reduction
  end

  test "catalog edits do not rewrite an existing grant" do
    membership = memberships(:jane)
    reduction = price_reduction(percentage: 10)
    membership.apply_price_reduction!(reduction)
    membership.save!
    reduction.update!(percentage: 80)

    assert_equal 10, membership.reload.membership_price_reduction.percentage
  end

  private

  def price_reduction(**attrs)
    PriceReduction.create!({
      names: { "en" => "Caritas" },
      percentage: 30
    }.merge(attrs))
  end

  def blank_grant_attributes(**attrs)
    {
      percentage: "",
      fixed_amount: ""
    }.merge(attrs)
  end
end

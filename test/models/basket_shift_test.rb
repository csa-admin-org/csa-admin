# frozen_string_literal: true

require "test_helper"

class BasketShiftTest < ActiveSupport::TestCase
  def setup
    @absence = absences(:jane_thursday_5)
    @source_basket = baskets(:jane_5) # Absence basket
    @target_basket = baskets(:jane_6) # Future basket
    @membership = @source_basket.membership
  end

  def build_basket_shift(absence: @absence, source_basket: @source_basket, target_basket: @target_basket)
    BasketShift.new(
      absence: absence,
      source_basket: source_basket,
      target_basket: target_basket)
  end

  test "validates source basket must be absent" do
    normal_basket = baskets(:jane_6)
    makeup = build_basket_shift(source_basket: normal_basket)

    assert_not makeup.valid?
    assert_includes makeup.errors[:source_basket], "is invalid"
  end

  test "validates source basket must not be empty" do
    @source_basket.decrement!(:quantity)
    @source_basket.baskets_basket_complements.first.decrement!(:quantity)
    assert @source_basket.empty?

    makeup = build_basket_shift

    assert_not makeup.valid?
    assert_includes makeup.errors[:source_basket], "is invalid"
  end

  test "validates target and source must share same membership" do
    makeup = build_basket_shift(target_basket: baskets(:john_7))

    assert_not makeup.valid?
    assert_includes makeup.errors[:target_basket], "is invalid"
  end

  test "validates target and source must not be absent" do
    makeup = build_basket_shift(target_basket: @source_basket)

    assert_not makeup.valid?
    assert_includes makeup.errors[:target_basket], "is invalid"
  end

  test "sets quantities on validation" do
    makeup = build_basket_shift

    assert makeup.valid?
    assert_equal({
      basket_size: { large_id => 1 },
      basket_complements: { bread_id => 1 }
    }, makeup.quantities)
  end

  test "moves quantities from source to target on creation" do
    makeup = build_basket_shift

    assert_difference(
      -> { @source_basket.reload.quantity } => -1,
      -> { @source_basket.baskets_basket_complements.first.quantity } => -1,
      -> { @target_basket.reload.quantity } => 1,
      -> { @target_basket.baskets_basket_complements.first.quantity } => 1,
      -> { @membership.reload.baskets_count } => -1
    ) do
      makeup.save!
    end
  end

  test "rolls back quantities from target to source on deletion" do
    makeup = build_basket_shift
    makeup.save!

    assert_difference(
      -> { @source_basket.reload.quantity } => 1,
      -> { @source_basket.baskets_basket_complements.first.quantity } => 1,
      -> { @target_basket.reload.quantity } => -1,
      -> { @target_basket.baskets_basket_complements.first.quantity } => -1,
      -> { @membership.reload.baskets_count } => 1
    ) do
      makeup.destroy!
    end
  end
end

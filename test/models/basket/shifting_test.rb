# frozen_string_literal: true

require "test_helper"

class Basket::ShiftingTest < ActiveSupport::TestCase
  test "decline shift" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?

    assert_changes -> { basket.reload.shift_declined_at }, from: nil do
      basket.update!(shift_target_basket_id: "declined")
    end
    assert basket.shift_declined?
    assert basket.can_be_shifted?
    assert_equal "declined", basket.shift_target_basket_id
  end

  test "cancel declined shift" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?
    basket.touch(:shift_declined_at)

    assert_changes -> { basket.reload.shift_declined_at }, to: nil do
      basket.update!(shift_target_basket_id: "")
    end
    assert basket.can_be_shifted?
    assert_not basket.shift_declined?
    assert_nil basket.shift_declined_at
    assert_not basket.shifted?
  end

  test "shift content to another basket" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?
    basket.touch(:shift_declined_at)

    assert_changes -> { basket.reload.shift_as_source }, from: nil do
      basket.update!(shift_target_basket_id: baskets(:jane_8).id)
    end
    assert_not basket.can_be_shifted?
    assert_nil basket.shift_declined_at
    assert basket.shifted?
    assert_equal baskets(:jane_8).id, basket.shift_target_basket_id
  end

  test "#member_shiftable_basket_targets" do
    org(basket_shift_deadline_in_weeks: nil)
    basket = baskets(:jane_5)
    travel_to basket.delivery.date

    assert basket.can_be_shifted?
    assert_not basket.membership.basket_shift_allowed?
    assert_empty basket.member_shiftable_basket_targets

    org(basket_shifts_annually: 1)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7),
      baskets(:jane_8),
      baskets(:jane_9),
      baskets(:jane_10)
    ], basket.member_shiftable_basket_targets

    org(basket_shift_deadline_in_weeks: 2)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets

    travel_to basket.delivery.date - 2.weeks
    assert_equal [
      baskets(:jane_4),
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets
  end
end

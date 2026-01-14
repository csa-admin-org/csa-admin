# frozen_string_literal: true

require "test_helper"

class Basket::ShiftingTest < ActiveSupport::TestCase
  test "can_be_shifted? returns true for absent billable basket" do
    basket = baskets(:jane_5)

    assert basket.absent?
    assert basket.billable?
    assert_not basket.empty?
    assert_not basket.shifted?
    assert basket.can_be_shifted?
  end

  test "can_be_shifted? returns false for absent non-billable basket" do
    basket = baskets(:jane_5)
    basket.update_column(:billable, false)

    assert basket.absent?
    assert_not basket.billable?
    assert_not basket.can_be_shifted?
  end

  test "can_be_shifted? returns false for non-absent basket" do
    basket = baskets(:jane_6)

    assert_not basket.absent?
    assert basket.billable?
    assert_not basket.can_be_shifted?
  end

  test "can_be_shifted? returns false for empty absent basket" do
    basket = baskets(:jane_5)
    basket.update_columns(quantity: 0)
    basket.baskets_basket_complements.delete_all

    assert basket.absent?
    assert basket.billable?
    assert_empty basket
    assert_not basket.can_be_shifted?
  end

  test "can_be_member_shifted? returns false for non-billable absent basket" do
    org(basket_shifts_annually: 1)
    basket = baskets(:jane_5)
    basket.update_column(:billable, false)

    assert basket.absent?
    assert_not basket.billable?
    assert_not basket.can_be_shifted?
    assert_not basket.can_be_member_shifted?
  end

  test "content_forfeited? returns true for non-billable absent basket" do
    basket = baskets(:jane_5)
    basket.update_column(:billable, false)

    assert basket.absent?
    assert_not basket.billable?
    assert basket.content_forfeited?
  end

  test "content_forfeited? returns true for empty absent basket" do
    basket = baskets(:jane_5)
    basket.update_columns(quantity: 0)
    basket.baskets_basket_complements.delete_all

    assert basket.absent?
    assert basket.billable?
    assert_empty basket
    assert basket.content_forfeited?
  end

  test "content_forfeited? returns false for billable non-empty absent basket" do
    basket = baskets(:jane_5)

    assert basket.absent?
    assert basket.billable?
    assert_not basket.empty?
    assert_not basket.content_forfeited?
  end

  test "content_forfeited? returns true for shifted basket (empty on source date)" do
    basket = baskets(:jane_5)
    basket.update!(shift_target_basket_id: baskets(:jane_8).id)
    basket.reload

    assert basket.absent?
    assert basket.shifted?
    assert_empty basket, "shifted basket is empty (quantity decremented)"
    assert basket.content_forfeited?, "shifted basket is forfeited on source date (nothing delivered here)"
  end

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

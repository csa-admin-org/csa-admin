# frozen_string_literal: true

require "test_helper"

class Liquid::BasketDropTest < ActiveSupport::TestCase
  def setup
    org(basket_shifts_annually: 1) # Enable basket shift feature
    @source_basket = baskets(:jane_5) # Absent basket
    @target_basket = baskets(:jane_6) # Future basket
  end

  test "shifted returns false when feature is disabled" do
    org(basket_shifts_annually: 0)
    create_basket_shift!
    drop = Liquid::BasketDrop.new(@target_basket)

    assert_not drop.shifted
  end

  test "shifts returns empty array when feature is disabled" do
    org(basket_shifts_annually: 0)
    create_basket_shift!
    drop = Liquid::BasketDrop.new(@target_basket)

    assert_empty drop.shifts
  end

  test "shifted returns false when basket has no shifts" do
    drop = Liquid::BasketDrop.new(@target_basket)

    assert_not drop.shifted
  end

  test "shifts returns empty array when basket has no shifts" do
    drop = Liquid::BasketDrop.new(@target_basket)

    assert_empty drop.shifts
  end

  test "shifted returns true when basket has received shifts" do
    create_basket_shift!
    drop = Liquid::BasketDrop.new(@target_basket)

    assert drop.shifted
  end

  test "shifts returns array of BasketShiftDrop when basket has received shifts" do
    shift = create_basket_shift!
    drop = Liquid::BasketDrop.new(@target_basket)

    assert_equal 1, drop.shifts.size
    assert_instance_of Liquid::BasketShiftDrop, drop.shifts.first
    assert_equal I18n.l(@source_basket.delivery.date), drop.shifts.first.old_delivery_date
    assert_equal I18n.l(@target_basket.delivery.date), drop.shifts.first.new_delivery_date
  end

  test "quantity reflects shifted baskets" do
    original_quantity = @target_basket.quantity
    create_basket_shift!
    drop = Liquid::BasketDrop.new(@target_basket.reload)

    assert_equal original_quantity + 1, drop.quantity
  end

  private

  def create_basket_shift!
    BasketShift.create!(
      absence: absences(:jane_thursday_5),
      source_basket: @source_basket,
      target_basket: @target_basket)
  end
end

# frozen_string_literal: true

require "test_helper"

class Basket::ForcedShiftTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
    org(
      features: [ :absence ],
      trial_baskets_count: 0,
      absences_billed: true,
      absences_included_mode: "provisional_delivery",
      basket_shifts_annually: 2,
      basket_shift_deadline_in_weeks: nil)
    @membership = memberships(:john)
    @membership.update!(absences_included_annually: 2)
  end

  test "admin shifts a year-end forced basket without an absence" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.first
    source_quantity = source.quantity
    target_quantity = target.quantity

    assert source.can_be_admin_shifted?
    assert_nil source.admin_shift_block_reason

    assert_no_difference -> { Absence.count } do
      assert_no_difference -> { @membership.forced_deliveries.count } do
        source.ensure_definite_absence!(admin: admins(:super))
        source.update!(shift_target_basket_id: target.id)
      end
    end

    source.reload
    target.reload

    assert source.forced?
    assert source.billable?
    assert source.shifted?
    assert_nil source.absence_id
    assert_equal 0, source.quantity
    assert_equal target_quantity + source_quantity, target.quantity
    assert target.billable?
    assert_not target.absent?
    assert_not target.forced?
    assert_nil source.shift_as_source.absence_id
    assert @membership.forced_deliveries.exists?(delivery: source.delivery)
  end

  test "member shifts a forced basket within the same deadline and period" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.coming.second

    assert source.can_be_member_shifted?
    assert_includes source.member_shiftable_basket_targets, target

    org(basket_shift_deadline_in_weeks: 1)
    source = Basket.find(source.id)

    assert_not_includes source.member_shiftable_basket_targets, target
    nearby = @membership.baskets.forced.first
    assert_includes source.member_shiftable_basket_targets, nearby
    assert source.member_off_cycle_shift_deliveries.all? { |delivery|
      delivery.date.in?(source.membership.period)
    }
    assert source.member_off_cycle_shift_deliveries.any?

    assert_no_difference -> { Absence.count } do
      source.update!(shift_target_basket_id: nearby.id)
    end

    assert source.reload.forced?
    assert source.shifted?
    assert_nil source.absence_id
    assert nearby.reload.deliverable?
  end

  test "member shifts a forced basket onto an off-cycle date inside the membership" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    thursday = source.member_off_cycle_shift_deliveries.find { |delivery|
      delivery.date > source.delivery.date
    }
    assert thursday
    assert_not @membership.delivery_cycle.include_delivery?(thursday)

    target = nil
    assert_no_difference -> { Absence.count } do
      assert_no_difference -> { @membership.forced_deliveries.count } do
        target = @membership.create_shift_receptacle!(thursday)
        source.update!(shift_target_basket_id: target.id)
      end
    end

    assert_equal @membership.basket_quantity, target.reload.quantity
    assert source.reload.forced?
    assert_equal 0, source.quantity
    assert_not ForcedDelivery.exists?(membership: @membership, delivery: thursday)
  end

  test "invoiced basket count and amount stay the same after the shift" do
    force_remaining_absences!
    @membership.baskets.update_all(delivery_cycle_price: 2)
    @membership.touch
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.first
    price = @membership.price
    sizes_price = @membership.basket_sizes_price
    deliveries_price = @membership.deliveries_price
    billed_quantity = @membership.baskets.billable.sum(:quantity)

    source.update!(shift_target_basket_id: target.id)
    @membership.reload

    assert source.reload.shifted?
    assert_equal 0, source.quantity
    assert_equal billed_quantity, @membership.baskets.billable.sum(:quantity)
    assert_equal sizes_price, @membership.basket_sizes_price
    assert_equal deliveries_price, @membership.deliveries_price
    assert_equal price, @membership.price

    invoice = create_membership_invoice(
      entity: @membership,
      member: @membership.member,
      membership_amount_fraction: 1)

    assert_equal price, invoice.memberships_amount
    assert_equal billed_quantity, @membership.baskets.billable.sum(:quantity)
  end

  test "shifting a forced basket does not reassign a provisional absence" do
    @membership.update!(absences_included_annually: 8)
    force_remaining_absences!
    travel_to "2024-05-01"
    delivered = @membership.baskets.normal.last
    assert delivered.delivery.date.past?
    assert delivered.billable?

    source = @membership.baskets.forced.last
    target = @membership.baskets.forced[-2]
    counting = @membership.send(:baskets_counting_as_absences_included).absent_or_forced.count

    source.update!(shift_target_basket_id: target.id)
    @membership.reload

    assert source.reload.shifted?
    assert_equal 0, source.quantity
    assert_empty @membership.baskets.provisionally_absent
    assert_equal counting, @membership.send(:baskets_counting_as_absences_included).absent_or_forced.count
    assert delivered.reload.normal?
    assert delivered.billable?
    assert source.reload.forced?
    assert_equal 8, @membership.baskets.absent_or_forced.count
  end

  test "undoing the shift restores the forced delivery and the price" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.first
    source_quantity = source.quantity
    target_quantity = target.quantity
    price = @membership.reload.price

    source.update!(shift_target_basket_id: target.id)
    source.reload.shift_as_source.destroy!
    @membership.reload

    assert source.reload.forced?
    assert_not source.shifted?
    assert source.can_unforce?
    assert_equal source_quantity, source.quantity
    assert_equal target_quantity, target.reload.quantity
    assert_equal price, @membership.price
    assert_empty @membership.baskets.provisionally_absent
  end

  test "a shifted forced source is struck and cannot be edited" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.coming.first
    source.update!(shift_target_basket_id: target.id)
    source.reload

    assert source.forced?
    assert_not source.absent?
    assert_empty source
    assert source.content_forfeited?
    assert_not source.can_member_update?
  end

  test "a later absence does not free the included slot of a shifted forced delivery" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.coming.first
    source_quantity = source.quantity
    target_quantity = target.quantity
    source.update!(shift_target_basket_id: target.id)
    counting = @membership.reload.send(:baskets_counting_as_absences_included).absent_or_forced.count

    absence = create_absence(
      member: @membership.member,
      started_on: source.delivery.date,
      ended_on: source.delivery.date)
    @membership.reload

    assert source.reload.forced?
    assert @membership.forced_deliveries.exists?(delivery: source.delivery)
    assert_equal counting, @membership.send(:baskets_counting_as_absences_included).absent_or_forced.count
    assert_empty @membership.baskets.provisionally_absent

    absence.destroy!
    @membership.reload

    assert source.reload.forced?
    assert source.shifted?
    assert_equal 0, source.quantity
    assert_equal target_quantity + source_quantity, target.reload.quantity
    assert @membership.forced_deliveries.exists?(delivery: source.delivery)
    assert_equal counting, @membership.send(:baskets_counting_as_absences_included).absent_or_forced.count
    assert_empty @membership.baskets.provisionally_absent
  end

  test "a shifted forced delivery cannot be canceled in place" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.first
    source.update!(shift_target_basket_id: target.id)
    forced_delivery = @membership.forced_deliveries.find_by!(delivery: source.delivery)

    assert_not source.reload.can_unforce?
    assert_not forced_delivery.destroy
    assert source.reload.forced?
    assert_empty @membership.baskets.provisionally_absent
  end

  test "recreating baskets keeps the forced shift and the absence quota" do
    force_remaining_absences!
    source = @membership.baskets.forced.last
    target = @membership.baskets.normal.coming.first
    assert target.delivery.date >= Date.current
    source_delivery = source.delivery
    target_delivery = target.delivery

    source.update!(shift_target_basket_id: target.id)
    @membership.update!(basket_quantity: 2)

    source = @membership.baskets.find_by!(delivery: source_delivery)
    target = @membership.baskets.find_by!(delivery: target_delivery)

    assert source.forced?
    assert_equal 0, source.quantity
    assert_equal 4, target.quantity
    assert target.billable?
    assert_empty @membership.baskets.provisionally_absent
    assert_equal 2, @membership.forced_deliveries.count
  end

  private

  def force_remaining_absences!
    travel_to @membership.absences_included_remindable_on
    assert_difference -> { @membership.forced_deliveries.count }, @membership.baskets.provisionally_absent.count do
      @membership.send_absences_included_reminder!
    end
    @membership.reload
    assert_equal 0, @membership.baskets.provisionally_absent.count
    assert @membership.baskets.forced.any?
  end
end

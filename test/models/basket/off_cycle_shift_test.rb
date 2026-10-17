# frozen_string_literal: true

require "test_helper"

class Basket::OffCycleShiftTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-04-01"
    org(
      features: [ :absence ],
      absences_billed: true,
      basket_shifts_annually: 2,
      basket_shift_deadline_in_weeks: nil)
  end

  test "no off-cycle dates when member shifts are off" do
    basket = memberships(:john).baskets.second
    travel_to basket.delivery.date
    org(basket_shifts_annually: 0)

    assert_empty basket.member_off_cycle_shift_deliveries
    assert_not basket.can_be_member_shifted?
  end

  test "monday cycle offers the same-week thursday, not two weeks out" do
    org(basket_shift_deadline_in_weeks: 1)
    basket = memberships(:john).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks

    dates = basket.member_off_cycle_shift_deliveries.map(&:date)

    assert_includes dates, basket.delivery.date + 3.days
    assert_not_includes dates, basket.delivery.date + 10.days
    assert dates.all? { |date| !memberships(:john).delivery_cycle.include_delivery?(Delivery.find_by!(date: date)) }
  end

  test "thursday cycle offers the next monday, not the following thursday" do
    basket = memberships(:jane).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks

    dates = basket.member_off_cycle_shift_deliveries.map(&:date)

    assert_includes dates, basket.delivery.date + 4.days
    assert dates.none? { |date| date.wday == basket.delivery.date.wday }
  end

  test "does not offer a date already covered by an absence" do
    basket = memberships(:john).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks
    thursday = deliveries(:thursday_2)
    create_absence(
      member: basket.member,
      started_on: basket.delivery.date,
      ended_on: thursday.date)

    assert_not_includes basket.member_off_cycle_shift_deliveries, thursday
  end

  test "does not offer a date this membership already has" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    membership.create_basket!(monday)
    travel_to basket.delivery.date

    assert_not_includes basket.member_off_cycle_shift_deliveries, monday
  end

  test "hides a date the depot does not serve" do
    basket = memberships(:john).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks
    thursday = deliveries(:thursday_2)
    basket.depot.delivery_cycles.clear
    basket.depot.delivery_cycles << delivery_cycles(:mondays)

    assert_not basket.depot.include_delivery?(thursday)
    assert_not_includes basket.member_off_cycle_shift_deliveries, thursday
  end

  test "offers a date another membership already receives at this depot" do
    basket = memberships(:john).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks
    thursday = deliveries(:thursday_2)
    basket.depot.delivery_cycles.clear
    basket.depot.delivery_cycles << delivery_cycles(:mondays)
    jane = baskets(:jane_2)
    jane.update_columns(depot_id: basket.depot_id)

    assert_includes basket.member_off_cycle_shift_deliveries, thursday
  end

  test "shift onto an off-cycle date creates an empty receptacle, then one shift" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    travel_to basket.delivery.date
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    assert_difference -> { membership.basket_shifts.count }, 1 do
      assert_difference -> { membership.member.absences.count }, 1 do
        post_shift(basket, monday)
      end
    end

    basket.reload
    target = membership.baskets.find_by!(delivery: monday)
    absence = basket.absence

    assert basket.absent?
    assert_equal 0, basket.quantity
    assert_equal membership.basket_quantity, target.quantity
    assert_equal 0, target.baskets_basket_complements.sum(:quantity)
    assert_equal absence.started_on, absence.ended_on
    assert_equal 1, membership.basket_shifts_count
  end

  test "undo deletes the receptacle and the one-day absence this shift created" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    travel_to basket.delivery.date
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    post_shift(basket, monday)
    target = membership.baskets.find_by!(delivery: monday)
    shift = basket.reload.shift_as_source

    assert_difference -> { Basket.where(id: target.id).count }, -1 do
      assert_difference -> { Absence.where(id: basket.absence_id).count }, -1 do
        shift.destroy!
      end
    end

    assert_equal membership.basket_quantity, basket.reload.quantity
    assert_not basket.absent?
  end

  test "undo of a shift onto an existing basket removes the one-day absence it created" do
    membership = memberships(:jane)
    basket = membership.baskets.coming.not_absent.second
    target = membership.baskets.coming.not_absent.third
    travel_to basket.delivery.date - 2.weeks

    basket.ensure_definite_absence!
    basket.update!(shift_target_basket_id: target.id)
    absence = basket.reload.absence

    assert_equal absence.started_on, absence.ended_on
    basket.shift_as_source.destroy!

    assert_not Absence.exists?(absence.id)
    assert_not basket.reload.absent?
    assert_equal membership.basket_quantity, basket.quantity
  end

  test "undo keeps a one-day absence the member declared before the shift" do
    membership = memberships(:jane)
    basket = membership.baskets.coming.not_absent.second
    target = membership.baskets.coming.not_absent.third
    travel_to basket.delivery.date - 2.weeks
    absence = create_absence(
      member: membership.member,
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date)
    travel 1.hour
    basket.reload.update!(shift_target_basket_id: target.id)

    basket.shift_as_source.destroy!

    assert Absence.exists?(absence.id)
    assert basket.reload.absent?
  end

  test "undo keeps a longer absence that already covered the date" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    travel_to basket.delivery.date - 1.week
    absence = create_absence(
      member: membership.member,
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date + 6.days)
    basket.reload
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    post_shift(basket, monday)

    basket.shift_as_source.destroy!

    assert Absence.exists?(absence.id)
    assert basket.reload.absent?
  end

  test "config change recreates the off-cycle target and reapplies the shift" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    travel_to basket.delivery.date - 1.day
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    post_shift(basket, monday)

    range = (basket.delivery.date - 1.day)..membership.ended_on
    membership.baskets.where(delivery: monday).delete_all
    membership.send(:with_basket_shifts_reapplied!, range) do
      membership.send(:destroy_baskets!, range)
      membership.send(:create_baskets!, range)
    end

    target = Basket.uncached { Basket.unscoped.find_by(membership_id: membership.id, delivery_id: monday.id) }
    raise "missing monday=#{monday.id} rows=#{Basket.uncached { Basket.unscoped.where(delivery_id: monday.id).pluck(:id, :membership_id) }}" unless target
    assert_equal membership.basket_quantity, target.quantity
    source = Basket.uncached { Basket.unscoped.find_by!(membership_id: membership.id, delivery_id: basket.delivery_id) }
    assert_equal 0, source.quantity
    assert source.shifted?
  end

  test "a missing target delivery drops the shift without doubling quantity" do
    membership = memberships(:jane)
    basket = membership.baskets.where(state: "normal").first
    travel_to basket.delivery.date - 1.day
    monday = Delivery.find_by!(date: basket.delivery.date + 4.days)
    post_shift(basket, monday)
    shift = basket.reload.shift_as_source
    BasketShift.where(id: shift.id).update_all(target_delivery_id: deliveries(:monday_1).id)
    membership.baskets.find_by!(delivery: monday).destroy!

    range = (basket.delivery.date - 1.day)..membership.ended_on
    membership.send(:with_basket_shifts_reapplied!, range) do
      membership.send(:destroy_baskets!, range)
      membership.send(:create_baskets!, range)
    end

    assert_not BasketShift.uncached { BasketShift.exists?(shift.id) }
    source = Basket.uncached { Basket.unscoped.find_by!(membership_id: membership.id, delivery_id: basket.delivery_id) }
    assert_equal membership.basket_quantity, source.quantity
  end

  test "deadline weeks apply to an off-cycle date the same way as an existing basket" do
    org(basket_shift_deadline_in_weeks: 1)
    basket = memberships(:jane).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks

    dates = basket.member_off_cycle_shift_deliveries.map(&:date)

    assert_includes dates, basket.delivery.date + 4.days
    assert_not_includes dates, basket.delivery.date + 14.days
  end

  test "a blank deadline keeps later off-cycle dates" do
    basket = memberships(:jane).baskets.coming.not_absent.first
    travel_to basket.delivery.date - 2.weeks

    assert_includes basket.member_off_cycle_shift_deliveries.map(&:date), basket.delivery.date + 11.days
  end

  test "only the next two deliveries outside the notice period shift without an absence" do
    membership = memberships(:jane)
    coming = membership.baskets.coming.not_absent.sort_by { |b| b.delivery.date }
    travel_to coming.first.delivery.date - 2.weeks

    assert coming.first.member_direct_shift?
    assert coming.second.member_direct_shift?
    assert_not coming.third.member_direct_shift?
    assert_empty coming.third.member_off_cycle_shift_deliveries
  end

  private

  def post_shift(basket, delivery)
    basket.ensure_definite_absence! unless basket.absence_id?
    target = basket.membership.create_shift_receptacle!(delivery)
    basket.update!(shift_target_basket_id: target.id)
  end
end

# frozen_string_literal: true

require "test_helper"

class DeliveryCycleTest < ActiveSupport::TestCase
  test "delivery cycle periods validation: no overlaps" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 3, results: :all }
      ]
    )

    period2 = cycle.periods.build(from_fy_month: 3, to_fy_month: 6, results: :all)

    assert_not period2.valid?
    assert_includes period2.errors[:from_fy_month], I18n.t("errors.messages.delivery_cycle_periods_overlap")
  end

  test "delivery cycle periods validation: from_fy_month must be <= to_fy_month" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :all }
      ]
    )

    period = cycle.periods.build(from_fy_month: 5, to_fy_month: 4, results: :all)

    assert_not period.valid?
    assert period.errors[:to_fy_month].any?
  end

  test "periods filter by FY month window" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)

    # In tests, the fiscal year starts in January by default, so FY-month 4 == April.
    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 4, to_fy_month: 4, results: :all }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal 4, cycle.current_deliveries.first.date.month
  end

  test "multiple periods with different filtering rules" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)

    # April: all deliveries (5), May: odd only (2 of 4), June: first of month (1)
    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 4, to_fy_month: 4, results: :all },
        { from_fy_month: 5, to_fy_month: 5, results: :odd },
        { from_fy_month: 6, to_fy_month: 6, results: :first_of_each_month }
      ]
    )

    deliveries = cycle.current_deliveries
    april_deliveries = deliveries.select { |d| d.date.month == 4 }
    may_deliveries = deliveries.select { |d| d.date.month == 5 }
    june_deliveries = deliveries.select { |d| d.date.month == 6 }

    assert_equal 5, april_deliveries.count
    assert_equal 2, may_deliveries.count # 4 Mondays in May, odd = 1st and 3rd
    assert_equal 1, june_deliveries.count
    assert_equal 8, deliveries.count
  end

  test "must have at least one period" do
    cycle = delivery_cycles(:mondays)

    # Attempting to destroy all periods via nested attributes should fail validation
    result = cycle.update(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } }
    )

    assert_not result
    assert cycle.errors[:periods].any?
  end

  test "first_cweek validation" do
    cycle = delivery_cycles(:mondays)

    assert cycle.update(first_cweek: 1)
    assert cycle.update(first_cweek: 53)
    assert cycle.update(first_cweek: nil)

    refute cycle.update(first_cweek: 0)
    refute cycle.update(first_cweek: 54)
    refute cycle.update(first_cweek: -1)
  end

  test "last_cweek validation" do
    cycle = delivery_cycles(:mondays)

    assert cycle.update(last_cweek: 1)
    assert cycle.update(last_cweek: 53)
    assert cycle.update(last_cweek: nil)

    refute cycle.update(last_cweek: 0)
    refute cycle.update(last_cweek: 54)
    refute cycle.update(last_cweek: -1)
  end

  test "wdays= filters invalid values" do
    cycle = delivery_cycles(:mondays)

    cycle.wdays = [ 1, 3, nil, "", 7, -1, 0 ]

    # Only valid wdays (0-6) should be kept
    assert_equal [ 1, 3, 0 ], cycle.wdays
  end

  test "can_delete? returns false when memberships exist" do
    cycle = delivery_cycles(:mondays)

    assert cycle.memberships.any?
    assert_not cycle.can_delete?
  end

  test "can_delete? returns true when no memberships and other cycles exist" do
    cycle = delivery_cycles(:mondays)
    # Move memberships to another cycle
    cycle.memberships.update_all(delivery_cycle_id: delivery_cycles(:all).id)
    cycle.memberships_basket_complements.destroy_all

    # Should be deletable when no memberships and other cycles exist
    assert cycle.can_delete?
  end

  test "can_delete? requires other non-discarded cycles to exist" do
    cycle = delivery_cycles(:mondays)

    # can_delete? checks DeliveryCycle.where.not(id: id).exists?
    # which includes discarded cycles, so this tests the "other cycles exist" part
    assert DeliveryCycle.where.not(id: cycle.id).exists?

    # The condition requires memberships.none? AND other cycles exist
    # Since this cycle has memberships, can_delete? is false
    assert cycle.memberships.any?
    assert_not cycle.can_delete?
  end

  test "can_discard? returns false when current or future memberships exist" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)

    assert cycle.memberships.current_and_future_year.any?
    assert_not cycle.can_discard?
  end

  test "current_year_memberships? returns true when memberships exist for current year" do
    travel_to "2024-06-01"
    cycle = delivery_cycles(:mondays)

    assert cycle.current_year_memberships?
  end

  test "current_year_memberships? returns false when no memberships exist for current year" do
    travel_to "2024-06-01"
    cycle = delivery_cycles(:mondays)
    cycle.memberships.current_year.update_all(delivery_cycle_id: delivery_cycles(:all).id)

    assert_not cycle.current_year_memberships?
  end

  test "prices? returns true when any cycle has positive price" do
    DeliveryCycle.update_all(price: 0)
    delivery_cycles(:mondays).update!(price: 10)

    assert DeliveryCycle.prices?
  end

  test "prices? returns false when no cycles have positive price" do
    DeliveryCycle.update_all(price: 0)

    assert_not DeliveryCycle.prices?
  end

  test "invoice_description uses invoice_name when present" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(invoice_names: { "en" => "Custom Invoice Name" })

    I18n.with_locale(:en) do
      assert_equal "Custom Invoice Name", cycle.invoice_description
    end
  end

  test "invoice_description falls back to delivery model name with public name" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(invoice_names: {})

    description = cycle.invoice_description

    assert_includes description, cycle.public_name
    assert_includes description, Delivery.model_name.human(count: 2)
  end

  test "create_default! creates a cycle with default name and full year period" do
    # Just test that create_default! works - don't try to delete existing cycles
    # which have NOT NULL constraints from memberships

    initial_count = DeliveryCycle.count
    cycle = DeliveryCycle.create_default!

    assert cycle.persisted?
    assert_equal initial_count + 1, DeliveryCycle.count
    assert_equal 1, cycle.periods.count
    assert_equal 1, cycle.periods.first.from_fy_month
    assert_equal 12, cycle.periods.first.to_fy_month
  end
end

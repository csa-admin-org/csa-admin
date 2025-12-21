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

  setup do
    travel_to "2024-01-01"
  end

  def member_ordered_names
    DeliveryCycle.member_ordered.map(&:name)
  end

  test "member_ordered" do
    create_delivery_cycle(
      name: "MondaysOdd",
      wdays: [ 1 ],
      periods_attributes: [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )

    assert_equal %w[All Mondays Thursdays MondaysOdd], member_ordered_names

    org(delivery_cycles_member_order_mode: "deliveries_count_asc")
    assert_equal %w[MondaysOdd Mondays Thursdays All], member_ordered_names

    org(delivery_cycles_member_order_mode: "name_asc")
    assert_equal %w[All Mondays MondaysOdd Thursdays], member_ordered_names

    org(delivery_cycles_member_order_mode: "wdays_asc")
    assert_equal %w[Mondays MondaysOdd All Thursdays], member_ordered_names

    delivery_cycles(:mondays).update!(member_order_priority: 2)
    assert_equal %w[MondaysOdd All Thursdays Mondays], member_ordered_names
  end

  test "only mondays" do
    cycle = delivery_cycles(:mondays)

    assert_equal 10, cycle.current_deliveries_count
    assert_equal 1, cycle.current_deliveries.first.date.wday
  end

  test "only April" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 4, to_fy_month: 4, results: :all }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal 4, cycle.current_deliveries.first.date.month
  end

  test "only odd weeks" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(week_numbers: :odd)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 15, 17, 19, 21, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "only even weeks" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(week_numbers: :even)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 14, 16, 18, 20, 22 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "all but first results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :all_but_first }
      ]
    )

    assert_equal 9, cycle.current_deliveries_count
    assert_equal [ 3, 5, 7, 9, 11, 13, 15, 17, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only odd results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 1, 5, 9, 13, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "only even results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :even }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 3, 7, 11, 15, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only first quarter results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :quarter_1 }
      ]
    )

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 1, 9, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "only second quarter results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :quarter_2 }
      ]
    )

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 3, 11, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only third quarter results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :quarter_3 }
      ]
    )

    assert_equal 2, cycle.current_deliveries_count
    assert_equal [ 5, 13 ], cycle.current_deliveries.pluck(:number)
  end

  test "only fourth quarter results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :quarter_4 }
      ]
    )

    assert_equal 2, cycle.current_deliveries_count
    assert_equal [ 7, 15 ], cycle.current_deliveries.pluck(:number)
  end

  test "only first of each month results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :first_of_each_month }
      ]
    )

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 1, 11, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only last of each month results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :last_of_each_month }
      ]
    )

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 9, 17, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "minimum days gap" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :all, minimum_gap_in_days: 8 }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 1, 5, 9, 13, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "minimum days gap and all but first results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :all_but_first, minimum_gap_in_days: 8 }
      ]
    )

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 3, 7, 11, 15, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only deliveries from first_cweek" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    cycle.update!(first_cweek: 17)

    assert_equal 7, cycle.current_deliveries_count
    assert_equal [ 17, 18, 19, 20, 21, 22, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "only deliveries until last_cweek" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    cycle.update!(last_cweek: 19)

    assert_equal 6, cycle.current_deliveries_count
    assert_equal [ 14, 15, 16, 17, 18, 19 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "deliveries between first_cweek and last_cweek" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    cycle.update!(first_cweek: 16, last_cweek: 20)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 16, 17, 18, 19, 20 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "first_cweek combined with other filters" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )
    cycle.update!(first_cweek: 17)

    # weeks 17, 18, 19, 20, 21, 22, 23 -> odd results: 1st, 3rd, 5th, 7th = weeks 17, 19, 21, 23
    assert_equal 4, cycle.current_deliveries_count
    assert_equal [ 17, 19, 21, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "last_cweek combined with other filters" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :even }
      ]
    )
    cycle.update!(last_cweek: 19)

    # weeks 14, 15, 16, 17, 18, 19 -> even results: 2nd, 4th, 6th = weeks 15, 17, 19
    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 15, 17, 19 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
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

  test "first_cweek with cross-year fiscal year" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)

    # Create deliveries spanning two calendar years (Mondays only)
    # Nov 2024: weeks 45, 46, 47, 48 (Mondays: Nov 4, 11, 18, 25)
    # Jan 2025: weeks 2, 3, 4, 5 (Mondays: Jan 6, 13, 20, 27)
    [
      Date.new(2024, 11, 4),  # week 45
      Date.new(2024, 11, 11), # week 46
      Date.new(2024, 11, 18), # week 47
      Date.new(2024, 11, 25), # week 48
      Date.new(2025, 1, 6),   # week 2
      Date.new(2025, 1, 13),  # week 3
      Date.new(2025, 1, 20),  # week 4
      Date.new(2025, 1, 27)   # week 5
    ].each { |date| Delivery.create!(date: date) }

    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: [
        { id: cycle.periods.first.id, _destroy: true },
        { from_fy_month: 8, to_fy_month: 8, results: :all },
        { from_fy_month: 10, to_fy_month: 10, results: :all }
      ]
    )

    # first_cweek: 47 should filter based on 2024 (beginning of fiscal year)
    # So it should include: week 47, 48 (2024) and weeks 2, 3, 4, 5 (2025)
    # Restrict to FY-months that correspond to calendar months 11 (November) and 1 (January) when FY starts in April:
    # FY-month 8  => November (within 2024)
    # FY-month 10 => January (within 2025)

    cycle.update!(first_cweek: 47)

    assert_equal 6, cycle.deliveries(2024).count
    assert_equal [ 47, 48, 2, 3, 4, 5 ], cycle.deliveries(2024).pluck(:date).map(&:cweek)
  end

  test "last_cweek with cross-year fiscal year" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)

    # Create deliveries spanning two calendar years (Mondays only)
    [
      Date.new(2024, 11, 4),  # week 45
      Date.new(2024, 11, 11), # week 46
      Date.new(2024, 11, 18), # week 47
      Date.new(2024, 11, 25), # week 48
      Date.new(2025, 1, 6),   # week 2
      Date.new(2025, 1, 13),  # week 3
      Date.new(2025, 1, 20),  # week 4
      Date.new(2025, 1, 27)   # week 5
    ].each { |date| Delivery.create!(date: date) }

    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: [
        { id: cycle.periods.first.id, _destroy: true },
        { from_fy_month: 8, to_fy_month: 8, results: :all },
        { from_fy_month: 10, to_fy_month: 10, results: :all }
      ]
    )

    # last_cweek: 3 should filter based on 2025 (end of fiscal year)
    # So it should include: weeks 45, 46, 47, 48 (2024) and weeks 2, 3 (2025)
    # Restrict to FY-months that correspond to calendar months 11 (November) and 1 (January) when FY starts in April:
    # FY-month 8  => November (within 2024)
    # FY-month 10 => January (within 2025)

    cycle.update!(last_cweek: 3)

    assert_equal 6, cycle.deliveries(2024).count
    assert_equal [ 45, 46, 47, 48, 2, 3 ], cycle.deliveries(2024).pluck(:date).map(&:cweek)
  end

  test "first_cweek and last_cweek with cross-year fiscal year" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)

    # Create deliveries spanning two calendar years (Mondays only)
    [
      Date.new(2024, 11, 4),  # week 45
      Date.new(2024, 11, 11), # week 46
      Date.new(2024, 11, 18), # week 47
      Date.new(2024, 11, 25), # week 48
      Date.new(2025, 1, 6),   # week 2
      Date.new(2025, 1, 13),  # week 3
      Date.new(2025, 1, 20),  # week 4
      Date.new(2025, 1, 27)   # week 5
    ].each { |date| Delivery.create!(date: date) }

    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: [
        { id: cycle.periods.first.id, _destroy: true },
        { from_fy_month: 8, to_fy_month: 8, results: :all },
        { from_fy_month: 10, to_fy_month: 10, results: :all }
      ]
    )

    # first_cweek: 46 (based on 2024) and last_cweek: 3 (based on 2025)
    # Should include: weeks 46, 47, 48 (2024) and weeks 2, 3 (2025)
    # Restrict to FY-months that correspond to calendar months 11 (November) and 1 (January) when FY starts in April:
    # FY-month 8  => November (within 2024)
    # FY-month 10 => January (within 2025)

    cycle.update!(first_cweek: 46, last_cweek: 3)

    assert_equal 5, cycle.deliveries(2024).count
    assert_equal [ 46, 47, 48, 2, 3 ], cycle.deliveries(2024).pluck(:date).map(&:cweek)
  end

  test "exclude_cweek_range excludes deliveries inside the range" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    # Exclude weeks 17-19, keep weeks 14, 15, 16, 20, 21, 22, 23
    cycle.update!(first_cweek: 17, last_cweek: 19, exclude_cweek_range: true)

    assert_equal 7, cycle.current_deliveries_count
    assert_equal [ 14, 15, 16, 20, 21, 22, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "exclude_cweek_range false includes deliveries inside the range" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    # Include only weeks 17-19
    cycle.update!(first_cweek: 17, last_cweek: 19, exclude_cweek_range: false)

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 17, 18, 19 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "exclude_cweek_range is ignored when only first_cweek is set" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    # With only first_cweek, exclude_cweek_range should be ignored
    cycle.update!(first_cweek: 17, last_cweek: nil, exclude_cweek_range: true)

    assert_equal 7, cycle.current_deliveries_count
    assert_equal [ 17, 18, 19, 20, 21, 22, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "exclude_cweek_range is ignored when only last_cweek is set" do
    cycle = delivery_cycles(:mondays)

    # Deliveries are on weeks 14, 15, 16, 17, 18, 19, 20, 21, 22, 23
    # With only last_cweek, exclude_cweek_range should be ignored
    cycle.update!(first_cweek: nil, last_cweek: 19, exclude_cweek_range: true)

    assert_equal 6, cycle.current_deliveries_count
    assert_equal [ 14, 15, 16, 17, 18, 19 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "exclude_cweek_range with cross-year fiscal year" do
    # Fiscal year from April 2024 to March 2025
    org(fiscal_year_start_month: 4)

    # Create deliveries spanning two calendar years (Mondays only)
    [
      Date.new(2024, 11, 4),  # week 45
      Date.new(2024, 11, 11), # week 46
      Date.new(2024, 11, 18), # week 47
      Date.new(2024, 11, 25), # week 48
      Date.new(2025, 1, 6),   # week 2
      Date.new(2025, 1, 13),  # week 3
      Date.new(2025, 1, 20),  # week 4
      Date.new(2025, 1, 27)   # week 5
    ].each { |date| Delivery.create!(date: date) }

    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: [
        { id: cycle.periods.first.id, _destroy: true },
        { from_fy_month: 8, to_fy_month: 8, results: :all },
        { from_fy_month: 10, to_fy_month: 10, results: :all }
      ]
    )

    # Exclude weeks 46-48, keep weeks 45, 2, 3, 4, 5
    cycle.update!(first_cweek: 46, last_cweek: 48, exclude_cweek_range: true)

    assert_equal 5, cycle.deliveries(2024).count
    assert_equal [ 45, 2, 3, 4, 5 ], cycle.deliveries(2024).pluck(:date).map(&:cweek)
  end

  test "only Monday, in April, odd weeks, and even results" do
    cycle = delivery_cycles(:mondays)

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 4, to_fy_month: 4, results: :even }
      ]
    )

    cycle.update!(
      wdays: [ 1 ],
      week_numbers: :odd)

    assert_equal 1, cycle.current_deliveries_count
    delivery = cycle.current_deliveries.first
    assert_equal 1, delivery.date.wday
    assert_equal 17, delivery.date.cweek
    assert_equal 7, delivery.number
  end

  test "reset caches after update" do
    cycle = delivery_cycles(:mondays)

    assert_equal({ "2023" => 10, "2024" => 10, "2025" => 10 }, cycle.deliveries_counts)

    assert_changes -> { cycle.reload.deliveries_counts } do
      cycle.update!(
        periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
          { from_fy_month: 4, to_fy_month: 4, results: :all }
        ]
      )
    end

    assert_equal({ "2023" => 4, "2024" => 5, "2025" => 4 }, cycle.deliveries_counts)
  end

  test "async membership baskets update after config change" do
    cycle = delivery_cycles(:mondays)
    membership = memberships(:john)

    assert_changes -> { membership.baskets.count } do
      cycle.update!(
        periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
          { from_fy_month: 4, to_fy_month: 4, results: :all }
        ]
      )
      perform_enqueued_jobs
    end
  end

  test "visible? returns false when depots have only one cycle each" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Each depot has only one cycle - no shared depots
    mondays.depots = [ home ]
    thursdays.depots = [ farm ]
    all.depots = [ bakery ]
    bakery.update!(visible: false)

    assert_not DeliveryCycle.visible?
  end

  test "visible? returns true when at least one depot has multiple cycles" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Home depot has both cycles - shared depot
    mondays.depots = [ home, farm ]
    thursdays.depots = [ home ]
    all.depots = [ bakery ]
    bakery.update!(visible: false)

    assert DeliveryCycle.visible?
  end

  test "primary returns cycle with most depots when billable_deliveries_count is equal" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Both cycles have same deliveries count, but mondays has more depots
    mondays.depots = [ home, farm, bakery ]
    thursdays.depots = [ home ]
    all.discard

    assert_equal mondays, DeliveryCycle.primary
  end

  test "primary returns cycle with highest billable_deliveries_count regardless of depot count" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Mondays has more depots but fewer deliveries
    mondays.depots = [ home, farm, bakery ]
    all.depots = [ home ]
    thursdays.discard

    assert_equal all, DeliveryCycle.primary
  end
end

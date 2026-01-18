# frozen_string_literal: true

require "test_helper"

class DeliveryCycle::DeliveriesTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
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

  test "for returns delivery cycles that include a delivery" do
    delivery = deliveries(:monday_1)

    cycles = DeliveryCycle.for(delivery)

    assert_includes cycles, delivery_cycles(:mondays)
    assert_includes cycles, delivery_cycles(:all)
    assert_not_includes cycles, delivery_cycles(:thursdays)
  end

  test "deliveries_in returns deliveries within a range" do
    cycle = delivery_cycles(:mondays)
    range = Date.new(2024, 4, 1)..Date.new(2024, 4, 30)

    deliveries = cycle.deliveries_in(range)

    assert deliveries.all? { |d| range.cover?(d.date) }
    assert_equal 5, deliveries.count
  end

  test "coming_deliveries returns future deliveries from current and next year" do
    travel_to "2024-05-01"
    cycle = delivery_cycles(:mondays)

    coming = cycle.coming_deliveries

    assert coming.all? { |d| d.date >= Date.current }
    assert coming.any?
  end

  test "next_delivery returns the next upcoming delivery" do
    travel_to "2024-05-01"
    cycle = delivery_cycles(:mondays)

    next_delivery = cycle.next_delivery

    assert next_delivery.date >= Date.current
  end

  test "deliveries_count prefers future year count when positive" do
    cycle = delivery_cycles(:mondays)

    # Both current and future years have deliveries
    assert cycle.future_deliveries_count.positive?
    assert_equal cycle.future_deliveries_count, cycle.deliveries_count
  end

  test "deliveries_count falls back to current year when future is zero" do
    # Create a new cycle with no future deliveries in its cache
    cycle = create_delivery_cycle(
      name: "TestCycle",
      wdays: [ 1 ],
      periods_attributes: [
        { from_fy_month: 4, to_fy_month: 4, results: :all }
      ]
    )

    # Manually set the cache to simulate no future deliveries
    cycle.update_column(:deliveries_counts, { Current.fy_year.to_s => 5, (Current.fy_year + 1).to_s => 0 })

    assert_equal 0, cycle.future_deliveries_count
    assert_equal cycle.current_deliveries_count, cycle.deliveries_count
  end
end

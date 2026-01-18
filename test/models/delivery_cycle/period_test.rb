# frozen_string_literal: true

require "test_helper"

class DeliveryCyclePeriodTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
  end

  test "valid period" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all
    assert_empty cycle.periods

    period = DeliveryCycle::Period.new(
      delivery_cycle: cycle,
      from_fy_month: 1,
      to_fy_month: 3,
      results: :all
    )

    assert period.valid?
  end

  test "period can be created" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 4,
      to_fy_month: 4,
      results: :all
    )

    assert period.persisted?
    assert_equal 1, cycle.periods.count
  end

  test "period can be updated" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 1,
      to_fy_month: 12,
      results: :all
    )

    period.update!(from_fy_month: 4, to_fy_month: 4)

    assert_equal 4, period.reload.from_fy_month
    assert_equal 4, period.to_fy_month
  end

  test "period can be destroyed" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 4,
      to_fy_month: 4,
      results: :all
    )

    assert_difference -> { DeliveryCycle::Period.count }, -1 do
      period.destroy!
    end
  end

  test "from_fy_month must be present and within 1..12" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: nil, to_fy_month: 3, results: :all)
    assert_not period.valid?
    assert period.errors[:from_fy_month].any?

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 0, to_fy_month: 3, results: :all)
    assert_not period.valid?
    assert period.errors[:from_fy_month].any?

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 13, to_fy_month: 3, results: :all)
    assert_not period.valid?
    assert period.errors[:from_fy_month].any?
  end

  test "to_fy_month must be present and within 1..12" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 1, to_fy_month: nil, results: :all)
    assert_not period.valid?
    assert period.errors[:to_fy_month].any?

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 1, to_fy_month: 0, results: :all)
    assert_not period.valid?
    assert period.errors[:to_fy_month].any?

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 1, to_fy_month: 13, results: :all)
    assert_not period.valid?
    assert period.errors[:to_fy_month].any?
  end

  test "from_fy_month must be <= to_fy_month" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.new(delivery_cycle: cycle, from_fy_month: 5, to_fy_month: 4, results: :all)

    assert_not period.valid?
    assert period.errors[:to_fy_month].any?
  end

  test "periods cannot overlap within a delivery cycle" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 2,
      to_fy_month: 4,
      results: :all
    )

    overlapping = DeliveryCycle::Period.new(
      delivery_cycle: cycle,
      from_fy_month: 4,
      to_fy_month: 6,
      results: :all
    )

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:from_fy_month], I18n.t("errors.messages.delivery_cycle_periods_overlap")
  end

  test "filter selects deliveries within FY month range" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 4,
      to_fy_month: 4,
      results: :all
    )

    # Use only Monday deliveries from the cycle (5 in April, 4 in May, 1 in June)
    # FY month 4 = April (when FY starts in January)
    monday_deliveries = cycle.reload.deliveries(2024)
    filtered = period.filter(monday_deliveries)

    assert filtered.all? { |d| d.date.month == 4 }
    assert_equal 5, filtered.count
  end

  test "filter applies results strategy" do
    cycle = delivery_cycles(:mondays)
    cycle.periods.delete_all

    period = DeliveryCycle::Period.create!(
      delivery_cycle: cycle,
      from_fy_month: 1,
      to_fy_month: 12,
      results: :odd
    )

    # Get raw Monday deliveries (before period filtering)
    # Mondays are wday 1, 10 deliveries in 2024 fixture
    monday_deliveries = Delivery
      .during_year(2024)
      .where("time_get_weekday(time_parse(date)) = 1")
      .order(:date)
      .to_a
    filtered = period.filter(monday_deliveries)

    # Odd results: 1st, 3rd, 5th, 7th, 9th = 5 deliveries
    assert_equal 5, filtered.count
  end

  test "apply_results with all_but_first" do
    period = DeliveryCycle::Period.new(results: :all_but_first)

    deliveries = Delivery.during_year(2024).order(:date).limit(5).to_a
    result = period.apply_results(deliveries)

    assert_equal 4, result.count
    assert_equal deliveries[1..], result
  end

  test "apply_results with first_of_each_month" do
    period = DeliveryCycle::Period.new(results: :first_of_each_month)

    deliveries = Delivery.during_year(2024).order(:date).to_a
    result = period.apply_results(deliveries)

    # Should have one delivery per month
    months = result.map { |d| d.date.month }.uniq
    assert_equal result.count, months.count
  end

  test "apply_results with last_of_each_month" do
    period = DeliveryCycle::Period.new(results: :last_of_each_month)

    deliveries = Delivery.during_year(2024).order(:date).to_a
    result = period.apply_results(deliveries)

    # Should have one delivery per month (the last one)
    months = result.map { |d| d.date.month }.uniq
    assert_equal result.count, months.count
  end

  test "apply_results with quarter selections" do
    deliveries = (1..8).map { |i| OpenStruct.new(date: Date.new(2024, 4, i)) }

    period = DeliveryCycle::Period.new(results: :quarter_1)
    assert_equal [ deliveries[0], deliveries[4] ], period.apply_results(deliveries)

    period = DeliveryCycle::Period.new(results: :quarter_2)
    assert_equal [ deliveries[1], deliveries[5] ], period.apply_results(deliveries)

    period = DeliveryCycle::Period.new(results: :quarter_3)
    assert_equal [ deliveries[2], deliveries[6] ], period.apply_results(deliveries)

    period = DeliveryCycle::Period.new(results: :quarter_4)
    assert_equal [ deliveries[3], deliveries[7] ], period.apply_results(deliveries)
  end
end

# frozen_string_literal: true

require "test_helper"

class Billing::PeriodsTest < ActiveSupport::TestCase
  test "build with annual billing returns one period spanning the full year" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 1)

    assert_equal 1, periods.size
    assert_equal Date.new(2024, 1, 1), periods[0].begin
    assert_equal Date.new(2025, 1, 1), periods[0].end
  end

  test "build with semi-annual billing returns two 6-month periods" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 2)

    assert_equal 2, periods.size
    assert_equal Date.new(2024, 1, 1), periods[0].begin
    assert_equal Date.new(2024, 7, 1), periods[0].end
    assert_equal Date.new(2024, 7, 1), periods[1].begin
    assert_equal Date.new(2025, 1, 1), periods[1].end
  end

  test "build with triannual billing returns three 4-month periods" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 3)

    assert_equal 3, periods.size
    assert_equal Date.new(2024, 1, 1), periods[0].begin
    assert_equal Date.new(2024, 5, 1), periods[0].end
    assert_equal Date.new(2024, 5, 1), periods[1].begin
    assert_equal Date.new(2024, 9, 1), periods[1].end
    assert_equal Date.new(2024, 9, 1), periods[2].begin
    assert_equal Date.new(2025, 1, 1), periods[2].end
  end

  test "build with quarterly billing returns four 3-month periods" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 4)

    assert_equal 4, periods.size
    expected = [
      [ Date.new(2024, 1, 1), Date.new(2024, 4, 1) ],
      [ Date.new(2024, 4, 1), Date.new(2024, 7, 1) ],
      [ Date.new(2024, 7, 1), Date.new(2024, 10, 1) ],
      [ Date.new(2024, 10, 1), Date.new(2025, 1, 1) ]
    ]
    periods.each_with_index do |period, i|
      assert_equal expected[i][0], period.begin, "period #{i} begin"
      assert_equal expected[i][1], period.end, "period #{i} end"
    end
  end

  test "build with monthly billing returns twelve 1-month periods" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 12)

    assert_equal 12, periods.size
    periods.each_with_index do |period, i|
      assert_equal Date.new(2024, i + 1, 1), period.begin
      expected_end = i == 11 ? Date.new(2025, 1, 1) : Date.new(2024, i + 2, 1)
      assert_equal expected_end, period.end
    end
  end

  test "build periods are contiguous with no gaps" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    [ 1, 2, 3, 4, 12 ].each do |division|
      periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: division)

      # First period starts at beginning of fiscal year
      assert_equal fy.beginning_of_year, periods.first.begin,
        "division=#{division}: first period should start at beginning of year"

      # Last period ends at beginning of next year
      assert_equal fy.end_of_year + 1.day, periods.last.end,
        "division=#{division}: last period should end at start of next year"

      # Each period starts where the previous one ended
      periods.each_cons(2) do |a, b|
        assert_equal a.end, b.begin,
          "division=#{division}: periods should be contiguous"
      end
    end
  end

  test "build periods use exclusive end ranges" do
    travel_to "2024-01-01"
    fy = FiscalYear.current

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 4)

    periods.each do |period|
      assert period.exclude_end?, "periods should use exclusive end ranges (...)"
    end
  end

  test "build with non-January fiscal year start shifts periods correctly" do
    org(fiscal_year_start_month: 4) # April → March
    travel_to "2024-04-01"
    fy = Current.org.fiscal_year_for(Date.current)

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 4)

    assert_equal 4, periods.size
    expected = [
      [ Date.new(2024, 4, 1), Date.new(2024, 7, 1) ],
      [ Date.new(2024, 7, 1), Date.new(2024, 10, 1) ],
      [ Date.new(2024, 10, 1), Date.new(2025, 1, 1) ],
      [ Date.new(2025, 1, 1), Date.new(2025, 4, 1) ]
    ]
    periods.each_with_index do |period, i|
      assert_equal expected[i][0], period.begin, "period #{i} begin"
      assert_equal expected[i][1], period.end, "period #{i} end"
    end
  end

  test "build with non-January fiscal year and monthly billing" do
    org(fiscal_year_start_month: 4) # April → March
    travel_to "2024-04-01"
    fy = Current.org.fiscal_year_for(Date.current)

    periods = Billing::Periods.build(fiscal_year: fy, billing_year_division: 12)

    assert_equal 12, periods.size
    assert_equal Date.new(2024, 4, 1), periods.first.begin
    assert_equal Date.new(2025, 4, 1), periods.last.end
  end

  test "last_fy_month returns fy_month of membership ended_on" do
    travel_to "2024-01-01"
    membership = memberships(:john) # ended_on: 2024-12-31

    result = Billing::Periods.last_fy_month(membership)

    assert_equal 12, result
  end

  test "last_fy_month with partial year membership" do
    travel_to "2024-01-01"
    membership = memberships(:bob) # ended_on: 2024-04-05

    result = Billing::Periods.last_fy_month(membership)

    assert_equal 4, result
  end

  test "last_fy_month with billing_ends_on_last_delivery_fy_month uses last delivery month" do
    org(billing_ends_on_last_delivery_fy_month: true)
    travel_to "2024-01-01"
    membership = memberships(:john) # ended_on: 2024-12-31

    last_delivery = membership.deliveries.last
    expected_fy_month = Current.org.fy_month_for(last_delivery.date)

    result = Billing::Periods.last_fy_month(membership)

    # Last delivery is before Dec 31, so it should use the delivery month
    assert_equal expected_fy_month, result
    assert result < 12, "last delivery month should be before December"
  end

  test "last_fy_month without billing_ends_on_last_delivery_fy_month ignores deliveries" do
    org(billing_ends_on_last_delivery_fy_month: false)
    travel_to "2024-01-01"
    membership = memberships(:john) # ended_on: 2024-12-31

    result = Billing::Periods.last_fy_month(membership)

    assert_equal 12, result
  end

  test "last_fy_month with non-January fiscal year" do
    org(fiscal_year_start_month: 4) # April → March
    travel_to "2024-04-01"
    membership = create_membership(
      started_on: Date.new(2024, 4, 1),
      ended_on: Date.new(2025, 3, 31)
    )

    result = Billing::Periods.last_fy_month(membership)

    # March is FY month 12 when fiscal year starts in April
    assert_equal 12, result
  end
end

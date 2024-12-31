# frozen_string_literal: true

require "test_helper"

class FiscalYearTest < ActiveSupport::TestCase
  test "current with start_month 1 beginning of year" do
    travel_to "2017-1-1"
    fy = FiscalYear.current
    assert_equal Date.new(2017, 1, 1), fy.beginning_of_year
    assert_equal Date.new(2017, 12, 31), fy.end_of_year
  end

  test "current with start_month 1 end of year" do
    travel_to "2017-12-31"
    fy = FiscalYear.current
    assert_equal Date.new(2017, 1, 1), fy.beginning_of_year
    assert_equal Date.new(2017, 12, 31), fy.end_of_year
  end

  test "current with start_month 4 beginning of year" do
    travel_to "2017-1-1"
    fy = FiscalYear.current(start_month: 4)
    assert_equal Date.new(2016, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2017, 3, 31), fy.end_of_year
    assert_equal 2016, fy.year
  end

  test "current with start_month 4 end of fiscal year" do
    travel_to "2017-3-31"
    fy = FiscalYear.current(start_month: 4)
    assert_equal Date.new(2016, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2017, 3, 31), fy.end_of_year
    assert_equal 2016, fy.year
  end

  test "current with start_month 4 beginning of fiscal year" do
    travel_to "2017-4-1"
    fy = FiscalYear.current(start_month: 4)
    assert_equal Date.new(2017, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2018, 3, 31), fy.end_of_year
    assert_equal 2017, fy.year
  end

  test "current with start_month 4 end of year" do
    travel_to "2017-12-31"
    fy = FiscalYear.current(start_month: 4)
    assert_equal Date.new(2017, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2018, 3, 31), fy.end_of_year
    assert_equal 2017, fy.year
  end

  test "for accepts past year" do
    fy = FiscalYear.for(2017, start_month: 4)
    assert_equal Date.new(2017, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2018, 3, 31), fy.end_of_year
  end

  test "for accepts future year" do
    fy = FiscalYear.for(2042, start_month: 4)
    assert_equal Date.new(2042, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2043, 3, 31), fy.end_of_year
  end

  test "for accepts past date" do
    fy = FiscalYear.for(Date.new(2017, 3, 31), start_month: 4)
    assert_equal Date.new(2016, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2017, 3, 31), fy.end_of_year
  end

  test "for accepts future date" do
    fy = FiscalYear.for(Date.new(2018, 4, 30), start_month: 4)
    assert_equal Date.new(2018, 4, 1), fy.beginning_of_year
    assert_equal Date.new(2019, 3, 31), fy.end_of_year
  end

  test "month returns same month number with start_month 1" do
    today = Date.current
    fy = FiscalYear.current
    assert_equal today.month, fy.month(today)
  end

  test "month returns month number since beginning_of_year" do
    fy = FiscalYear.for(2017, start_month: 4)
    assert_equal 1, fy.month(Date.new(2017, 4, 1))
    assert_equal 9, fy.month(Date.new(2017, 12, 1))
    assert_equal 12, fy.month(Date.new(2018, 3, 1))
  end

  test "current_quarter_range returns Q3 range" do
    travel_to "2020-08-12"
    fy = FiscalYear.for(2020)
    assert_equal Time.new(2020, 7)..Time.new(2020, 9, 30).end_of_day, fy.current_quarter_range
  end

  test "current_quarter_range returns Q2 range" do
    travel_to "2020-08-31"
    fy = FiscalYear.for(2020, start_month: 4)
    assert_equal Time.new(2020, 7)..Time.new(2020, 9, 30).end_of_day, fy.current_quarter_range
  end

  test "current_quarter_range returns Q4 range" do
    travel_to "2020-01-01"
    fy = FiscalYear.for(2020, start_month: 2)
    travel_to(fy.end_of_year)
    assert_equal Time.new(2020, 11)..Time.new(2021, 1, 31).end_of_day, fy.current_quarter_range
  end

  test "current_quarter_range returns Q1 range" do
    travel_to "2020-01-01"
    fy = FiscalYear.for(2020, start_month: 3)
    travel_to("2020-03-01")
    assert_equal Time.new(2020, 3)..Time.new(2020, 5, 31).end_of_day, fy.current_quarter_range
  end
end

# frozen_string_literal: true

require "test_helper"

class Membership::TimeframeTest < ActiveSupport::TestCase
  # Note: Presence validation tests are omitted because the model's before_validation
  # callback fails before validation runs when dates are nil. The validation itself
  # is provided by HasDateRange and tested in membership_test.rb.

  test "validates started_on must be before ended_on" do
    membership = build_membership(
      started_on: Date.new(2024, 6, 15),
      ended_on: Date.new(2024, 6, 1))

    assert_not membership.valid?
    assert_includes membership.errors[:started_on], "must be before the end"
    assert_includes membership.errors[:ended_on], "must be after the start"
  end

  test "validates started_on and ended_on must be in the same fiscal year" do
    membership = build_membership(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2025, 6, 30))

    assert_not membership.valid?
    assert_includes membership.errors[:started_on], "must be in the same fiscal year"
    assert_includes membership.errors[:ended_on], "must be in the same fiscal year"
  end

  test "period returns date range" do
    membership = build_membership(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 12, 31))

    assert_equal Date.new(2024, 1, 1)..Date.new(2024, 12, 31), membership.period
    assert_equal membership.period, membership.date_range
  end

  test "display_period formats dates" do
    membership = build_membership(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 12, 31))

    assert_includes membership.display_period, "–"
  end

  test "fiscal_year returns fiscal year for started_on" do
    membership = build_membership(
      started_on: Date.new(2024, 4, 1),
      ended_on: Date.new(2024, 12, 31))

    assert_equal 2024, membership.fiscal_year.year
  end

  test "fy_year returns fiscal year number" do
    membership = build_membership(
      started_on: Date.new(2024, 4, 1),
      ended_on: Date.new(2024, 12, 31))

    assert_equal 2024, membership.fy_year
  end

  test "past? returns true when ended_on is before today" do
    travel_to "2025-06-01"
    membership = memberships(:john) # 2024-01-01 to 2024-12-31

    assert membership.past?
    assert_not membership.current?
    assert_not membership.future?
  end

  test "current? returns true when today is within the date range" do
    travel_to "2024-06-01"
    membership = memberships(:john) # 2024-01-01 to 2024-12-31

    assert membership.current?
    assert_not membership.past?
    assert_not membership.future?
  end

  test "future? returns true when started_on is after today" do
    travel_to "2024-06-01"
    membership = memberships(:john_future) # 2025-01-01 to 2025-12-31

    assert membership.future?
    assert_not membership.current?
    assert_not membership.past?
  end

  test "started? returns true when started_on is today or in the past" do
    travel_to "2024-06-01"

    assert memberships(:john).started?
    assert_not memberships(:john_future).started?
  end

  test "current_year? returns true when membership is in current fiscal year" do
    travel_to "2024-06-01"

    assert memberships(:john).current_year?
    assert_not memberships(:john_future).current_year?
  end

  test "current_or_future_year? returns true for current and future fiscal years" do
    travel_to "2024-06-01"

    assert memberships(:john).current_or_future_year?
    assert memberships(:john_future).current_or_future_year?
    assert_not memberships(:john_past).current_or_future_year?
  end

  test "scope past returns memberships that have ended" do
    travel_to "2025-06-01"

    past_memberships = Membership.past
    assert_includes past_memberships, memberships(:john)
    assert_not_includes past_memberships, memberships(:john_future)
  end

  test "scope future returns memberships that have not started" do
    travel_to "2024-06-01"

    future_memberships = Membership.future
    assert_includes future_memberships, memberships(:john_future)
    assert_not_includes future_memberships, memberships(:john)
  end

  test "scope current returns memberships active today" do
    travel_to "2024-06-01"

    current_memberships = Membership.current
    assert_includes current_memberships, memberships(:john)
    assert_not_includes current_memberships, memberships(:john_future)
  end

  test "scope current_or_future returns current and future memberships ordered by started_on" do
    travel_to "2024-06-01"

    result = Membership.current_or_future
    assert_includes result, memberships(:john)
    assert_includes result, memberships(:john_future)
    assert_not_includes result, memberships(:john_past)
  end

  test "scope including_date returns memberships active on given date" do
    result = Membership.including_date(Date.new(2024, 6, 1))
    assert_includes result, memberships(:john)
    assert_not_includes result, memberships(:john_future)
    assert_not_includes result, memberships(:john_past)
  end

  test "scope during_year returns memberships within fiscal year" do
    assert_includes Membership.during_year(2024), memberships(:john)
    assert_includes Membership.during_year(2025), memberships(:john_future)
    assert_not_includes Membership.during_year(2024), memberships(:john_future)
    assert_not_includes Membership.during_year(2025), memberships(:john)
  end

  test "scope overlaps returns memberships overlapping with given range" do
    range = Date.new(2024, 6, 1)..Date.new(2024, 6, 30)

    overlapping = Membership.overlaps(range)
    assert_includes overlapping, memberships(:john)
    assert_not_includes overlapping, memberships(:john_future)
    assert_not_includes overlapping, memberships(:john_past)
  end

  test "scope duration_gt returns memberships longer than given days" do
    # john's membership is a full year (365 days)
    long_memberships = Membership.duration_gt(300)
    assert_includes long_memberships, memberships(:john)
    # bob's membership is short (about 3 months)
    assert_not_includes long_memberships, memberships(:bob)
  end

  test "scope started returns memberships that have started" do
    travel_to "2024-06-01"

    started_memberships = Membership.started
    assert_includes started_memberships, memberships(:john)
    assert_not_includes started_memberships, memberships(:john_future)
  end

  test "scope current_year returns memberships in current fiscal year" do
    travel_to "2024-06-01"

    current_year_memberships = Membership.current_year
    assert_includes current_year_memberships, memberships(:john)
    assert_not_includes current_year_memberships, memberships(:john_future)
    assert_not_includes current_year_memberships, memberships(:john_past)
  end

  test "scope current_and_future_year returns memberships from current year onwards" do
    travel_to "2024-06-01"

    result = Membership.current_and_future_year
    assert_includes result, memberships(:john)
    assert_includes result, memberships(:john_future)
    assert_not_includes result, memberships(:john_past)
  end

  test "during_year is a ransackable scope" do
    assert_includes Membership.ransackable_scopes, :during_year
  end
end

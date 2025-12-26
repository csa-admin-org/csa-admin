# frozen_string_literal: true

require "test_helper"

class HasDateRangeTest < ActiveSupport::TestCase
  # Use Absence as the test subject since it directly includes HasDateRange
  def build_record(started_on:, ended_on:)
    Absence.new(
      member: members(:john),
      admin: admins(:ultra), # Skip absence-specific date validations
      started_on: started_on,
      ended_on: ended_on
    )
  end

  # Validations

  test "validates presence of started_on" do
    record = build_record(started_on: nil, ended_on: Date.current + 1.week)

    assert_not record.valid?
    assert_includes record.errors[:started_on], "can't be blank"
  end

  test "validates presence of ended_on" do
    record = build_record(started_on: Date.current, ended_on: nil)

    assert_not record.valid?
    assert_includes record.errors[:ended_on], "can't be blank"
  end

  test "validates started_on must be before ended_on" do
    record = build_record(
      started_on: Date.new(2024, 6, 15),
      ended_on: Date.new(2024, 6, 1)
    )

    assert_not record.valid?
    assert_includes record.errors[:started_on], "must be before the end"
    assert_includes record.errors[:ended_on], "must be after the start"
  end

  test "validates started_on can equal ended_on minus one day" do
    record = build_record(
      started_on: Date.new(2024, 6, 1),
      ended_on: Date.new(2024, 6, 2)
    )

    assert record.valid?
  end

  # Instance methods

  test "date_range returns started_on..ended_on" do
    record = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 12, 31)
    )

    assert_equal Date.new(2024, 1, 1)..Date.new(2024, 12, 31), record.date_range
  end

  test "past? returns true when ended_on is before today" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 5, 31)
    )

    assert record.past?
  end

  test "past? returns false when ended_on is today or later" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 6, 1)
    )

    assert_not record.past?
  end

  test "future? returns true when started_on is after today" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 6, 2),
      ended_on: Date.new(2024, 12, 31)
    )

    assert record.future?
  end

  test "future? returns false when started_on is today or earlier" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 6, 1),
      ended_on: Date.new(2024, 12, 31)
    )

    assert_not record.future?
  end

  test "current? returns true when today is within the date range" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 12, 31)
    )

    assert record.current?
  end

  test "current? returns false when today is outside the date range" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 7, 1),
      ended_on: Date.new(2024, 12, 31)
    )

    assert_not record.current?
  end

  test "present_or_future? returns true when ended_on is today or later" do
    travel_to "2024-06-01"

    # Ended today
    record1 = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 6, 1)
    )
    assert record1.present_or_future?

    # Ends in the future
    record2 = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 12, 31)
    )
    assert record2.present_or_future?
  end

  test "present_or_future? returns false when ended_on is before today" do
    travel_to "2024-06-01"
    record = build_record(
      started_on: Date.new(2024, 1, 1),
      ended_on: Date.new(2024, 5, 31)
    )

    assert_not record.present_or_future?
  end

  # Scopes

  test "scope past returns records that have ended" do
    travel_to "2024-06-01"
    create_absence(started_on: "2024-01-01", ended_on: "2024-05-31")

    assert_includes Absence.past, Absence.last
  end

  test "scope future returns records that have not started" do
    travel_to "2024-06-01"
    create_absence(started_on: "2024-06-02", ended_on: "2024-12-31")

    assert_includes Absence.future, Absence.last
  end

  test "scope current returns records active today" do
    travel_to "2024-06-01"
    create_absence(started_on: "2024-01-01", ended_on: "2024-12-31")

    assert_includes Absence.current, Absence.last
  end

  test "scope present_or_future returns records ending today or later" do
    travel_to "2024-06-01"

    # Ends today
    create_absence(started_on: "2024-01-01", ended_on: "2024-06-01")
    ending_today = Absence.last

    # Ends in the future
    create_absence(started_on: "2024-01-01", ended_on: "2024-12-31")
    future = Absence.last

    result = Absence.present_or_future
    assert_includes result, ending_today
    assert_includes result, future
  end

  test "scope including_date returns records active on given date" do
    create_absence(started_on: "2024-01-01", ended_on: "2024-06-30")
    absence = Absence.last

    assert_includes Absence.including_date(Date.new(2024, 3, 15)), absence
    assert_not_includes Absence.including_date(Date.new(2024, 7, 1)), absence
  end

  test "scope overlaps returns records overlapping with given range" do
    create_absence(started_on: "2024-03-01", ended_on: "2024-06-30")
    absence = Absence.last

    # Overlapping ranges
    assert_includes Absence.overlaps(Date.new(2024, 1, 1)..Date.new(2024, 4, 1)), absence
    assert_includes Absence.overlaps(Date.new(2024, 5, 1)..Date.new(2024, 8, 1)), absence
    assert_includes Absence.overlaps(Date.new(2024, 4, 1)..Date.new(2024, 5, 1)), absence

    # Non-overlapping range
    assert_not_includes Absence.overlaps(Date.new(2024, 7, 1)..Date.new(2024, 8, 1)), absence
  end

  test "scope during_year returns records that touch the fiscal year" do
    travel_to "2024-06-01"

    # Starts and ends in 2024
    create_absence(started_on: "2024-03-01", ended_on: "2024-06-30")
    in_2024 = Absence.last

    # Starts in 2024, ends in 2025
    create_absence(started_on: "2024-11-01", ended_on: "2025-02-28")
    spanning = Absence.last

    result_2024 = Absence.during_year(2024)
    assert_includes result_2024, in_2024
    assert_includes result_2024, spanning

    result_2025 = Absence.during_year(2025)
    assert_not_includes result_2025, in_2024
    assert_includes result_2025, spanning
  end
end

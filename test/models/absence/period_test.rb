# frozen_string_literal: true

require "test_helper"

class Absence::PeriodTest < ActiveSupport::TestCase
  test "validates started_on and ended_on dates when submitted by member" do
    travel_to "2024-01-15"
    absence = Absence.new(
      member: members(:john),
      started_on: 6.days.from_now,
      ended_on: 2.years.from_now)

    assert_not absence.valid?
    assert_includes absence.errors[:started_on], "must be after or equal to 22 January 2024"
    assert_includes absence.errors[:ended_on], "must be before 19 January 2025"
  end

  test "does not validate started_on and ended_on dates when submitted by admin" do
    absence = Absence.new(
      member: members(:john),
      admin: admins(:ultra),
      started_on: Date.current,
      ended_on: 2.years.from_now)

    assert absence.valid?
  end
end

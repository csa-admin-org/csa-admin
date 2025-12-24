# frozen_string_literal: true

require "test_helper"

class AbsenceFeatureTest < ActiveSupport::TestCase
  test "absences_included_mode must be present" do
    org = organizations(:acme)
    org.absences_included_mode = nil

    assert_not org.valid?
    assert_includes org.errors[:absences_included_mode], "can't be blank"
  end

  test "absences_included_mode must be a valid value" do
    org = organizations(:acme)

    org.absences_included_mode = "provisional_absence"
    assert org.valid?

    org.absences_included_mode = "provisional_delivery"
    org.absences_included_reminder_weeks_before = 2
    assert org.valid?

    org.absences_included_mode = "invalid_mode"
    assert_not org.valid?
    assert_includes org.errors[:absences_included_mode], "is not included in the list"
  end

  test "absences_included_reminder_weeks_before must be at least 1" do
    org = organizations(:acme)

    org.absences_included_reminder_weeks_before = 0
    assert_not org.valid?
    assert_includes org.errors[:absences_included_reminder_weeks_before], "must be greater than or equal to 1"

    org.absences_included_reminder_weeks_before = 1
    assert org.valid?

    org.absences_included_reminder_weeks_before = 4
    assert org.valid?
  end

  test "absences_included_reminder_weeks_before defaults to 4" do
    org = organizations(:acme)

    assert_equal 4, org.absences_included_reminder_weeks_before
  end

  test "absences_included_provisional_absence_mode? returns true for provisional_absence mode" do
    org = organizations(:acme)
    org.absences_included_mode = "provisional_absence"

    assert org.absences_included_provisional_absence_mode?
    assert_not org.absences_included_provisional_delivery_mode?
  end

  test "absences_included_provisional_delivery_mode? returns true for provisional_delivery mode" do
    org = organizations(:acme)
    org.absences_included_mode = "provisional_delivery"
    org.absences_included_reminder_weeks_before = 2

    assert org.absences_included_provisional_delivery_mode?
    assert_not org.absences_included_provisional_absence_mode?
  end

  test "absences_included_reminder_enabled? always returns true" do
    org = organizations(:acme)

    assert org.absences_included_reminder_enabled?
  end
end

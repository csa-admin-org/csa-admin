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
    assert org.valid?

    org.absences_included_mode = "invalid_mode"
    assert_not org.valid?
    assert_includes org.errors[:absences_included_mode], "is not included in the list"
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

    assert org.absences_included_provisional_delivery_mode?
    assert_not org.absences_included_provisional_absence_mode?
  end
end

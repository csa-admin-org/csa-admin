# frozen_string_literal: true

require "test_helper"

class DeliveryCycle::AuditingTest < ActiveSupport::TestCase
  test "audits changes to tracked attributes" do
    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(absences_included_annually: 5)
    end

    audit = cycle.audits.last
    assert_equal({ "absences_included_annually" => [ 0, 5 ] }, audit.audited_changes)
  end

  test "audits changes to price" do
    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(price: 10.0)
    end

    audit = cycle.audits.last
    assert_equal [ 0.0, 10.0 ], audit.audited_changes["price"].map(&:to_f)
  end

  test "audits changes to week_numbers" do
    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(week_numbers: :odd)
    end

    audit = cycle.audits.last
    assert_equal "all", audit.audited_changes["week_numbers"].first
    assert_equal "odd", audit.audited_changes["week_numbers"].last
  end

  test "audits changes to wdays" do
    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(wdays: [ 1, 3 ])
    end

    audit = cycle.audits.last
    assert_equal [ 1 ], audit.audited_changes["wdays"].first
    assert_equal [ 1, 3 ], audit.audited_changes["wdays"].last
  end

  test "audits changes to periods when adding" do
    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        periods_attributes: [
          { id: cycle.periods.first.id, from_fy_month: 1, to_fy_month: 6 },
          { from_fy_month: 7, to_fy_month: 12, results: :odd }
        ]
      )
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("periods")
    changes = audit.audited_changes["periods"]
    assert_equal 1, changes.first.size # was one period
    assert_equal 2, changes.last.size # now two periods
  end

  test "audits removal of periods" do
    cycle = delivery_cycles(:mondays)
    # Modify existing period to only cover first half of year
    first_period = cycle.periods.first
    first_period.update_columns(from_fy_month: 1, to_fy_month: 6)
    # Add a second period for second half of year
    second_period = cycle.periods.create!(from_fy_month: 7, to_fy_month: 12, results: :odd)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        periods_attributes: [
          { id: first_period.id, from_fy_month: 1, to_fy_month: 12 },
          { id: second_period.id, _destroy: "1" }
        ]
      )
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("periods")
    changes = audit.audited_changes["periods"]
    assert_equal 2, changes.first.size # had two periods
    assert_equal 1, changes.last.size # now one period
  end

  test "audits changes to period configuration" do
    cycle = delivery_cycles(:mondays)
    period = cycle.periods.first

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        periods_attributes: [
          { id: period.id, from_fy_month: 1, to_fy_month: 12, results: :even }
        ]
      )
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("periods")
    changes = audit.audited_changes["periods"]
    # Before: all results
    assert_equal "all", changes.first.first["results"]
    # After: even results
    assert_equal "even", changes.last.first["results"]
  end

  test "does not audit when no attribute changes" do
    cycle = delivery_cycles(:mondays)

    assert_no_difference(-> { Audit.where(auditable: cycle).count }) do
      cycle.save!
    end
  end

  test "does not audit translated hash when all values are blank" do
    cycle = delivery_cycles(:mondays)
    # Set invoice_names to all blank values
    cycle.update_columns(invoice_names: { "fr" => "", "en" => "" })

    assert_no_difference(-> { Audit.where(auditable: cycle).count }) do
      # Updating with same blank values should not create an audit
      cycle.update!(invoice_names: { "fr" => "", "en" => "" })
    end
  end

  test "does not include translated hash in audit when unchanged from blank to blank" do
    cycle = delivery_cycles(:mondays)
    cycle.update_columns(invoice_names: { "fr" => "", "en" => "" })

    # Make a real change along with a no-op translated hash change
    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(absences_included_annually: 3, invoice_names: { "fr" => "", "en" => "" })
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("absences_included_annually")
    assert_not audit.audited_changes.key?("invoice_names"), "invoice_names should not be in audit when unchanged"
  end

  test "records session when auditing" do
    travel_to "2024-01-01"
    admin = admins(:super)
    session = create_session(admin)
    Current.session = session

    cycle = delivery_cycles(:mondays)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(absences_included_annually: 3)
    end

    audit = cycle.audits.last
    assert_equal session, audit.session
    assert_equal admin, audit.actor
  end

  test "combines attribute and periods changes into a single audit" do
    cycle = delivery_cycles(:mondays)
    period = cycle.periods.first

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        absences_included_annually: 2,
        week_numbers: :odd,
        periods_attributes: [
          { id: period.id, from_fy_month: 1, to_fy_month: 6 },
          { from_fy_month: 7, to_fy_month: 12 }
        ]
      )
    end

    audit = cycle.audits.last
    # All changes in the same audit
    assert audit.audited_changes.key?("absences_included_annually"), "Expected absences_included_annually in audited changes"
    assert audit.audited_changes.key?("week_numbers"), "Expected week_numbers in audited changes"
    assert audit.audited_changes.key?("periods"), "Expected periods in audited changes"
  end

  test "audits translated attribute changes" do
    cycle = delivery_cycles(:mondays)
    original_names = cycle.names.dup

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(name_en: "Updated Monday Deliveries")
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("names")
    assert_equal original_names, audit.audited_changes["names"].first
    assert_equal "Updated Monday Deliveries", audit.audited_changes["names"].last["en"]
  end

  test "only stores changed periods, not unchanged ones" do
    cycle = delivery_cycles(:mondays)
    # Set up two periods: Jan-Apr and Oct-Dec
    first_period = cycle.periods.first
    first_period.update_columns(from_fy_month: 1, to_fy_month: 4)
    second_period = cycle.periods.create!(from_fy_month: 10, to_fy_month: 12, results: :all)

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        periods_attributes: [
          { id: first_period.id, from_fy_month: 1, to_fy_month: 4, results: :all }, # unchanged
          { id: second_period.id, from_fy_month: 10, to_fy_month: 12, results: :odd } # changed
        ]
      )
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("periods")
    changes = audit.audited_changes["periods"]

    # Only the changed period (Oct-Dec) should be in the audit, not the unchanged one (Jan-Apr)
    assert_equal 1, changes.first.size, "Before should only contain the changed period"
    assert_equal 1, changes.last.size, "After should only contain the changed period"
    assert_equal 10, changes.first.first["from_fy_month"]
    assert_equal "all", changes.first.first["results"]
    assert_equal "odd", changes.last.first["results"]
  end

  test "properly tracks period modification when month range changes" do
    cycle = delivery_cycles(:mondays)
    period = cycle.periods.first
    original_id = period.id

    # Change the period's month range (from full year to first half)
    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        periods_attributes: [
          { id: period.id, from_fy_month: 1, to_fy_month: 6, results: :odd }
        ]
      )
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("periods")
    changes = audit.audited_changes["periods"]

    # Should show as one modification, not as remove + add
    assert_equal 1, changes.first.size, "Before should contain one period"
    assert_equal 1, changes.last.size, "After should contain one period"
    # Both should have the same record ID
    assert_equal original_id, changes.first.first["id"]
    assert_equal original_id, changes.last.first["id"]
    # But different month ranges
    assert_equal 12, changes.first.first["to_fy_month"]
    assert_equal 6, changes.last.first["to_fy_month"]
  end

  test "audits depot_ids changes when adding depots" do
    cycle = delivery_cycles(:mondays)
    new_depot = depots(:farm)

    # Ensure new_depot is not already associated
    cycle.depots.delete(new_depot)
    depot_ids_before_add = cycle.depot_ids.sort

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(depot_ids: depot_ids_before_add + [ new_depot.id ])
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("depot_ids")
    changes = audit.audited_changes["depot_ids"]
    assert_not_includes changes.first, new_depot.id
    assert_includes changes.last, new_depot.id
  end

  test "audits depot_ids changes when removing depots" do
    cycle = delivery_cycles(:mondays)
    depot_to_remove = cycle.depots.first
    original_depot_ids = cycle.depot_ids.sort

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(depot_ids: original_depot_ids - [ depot_to_remove.id ])
    end

    audit = cycle.audits.last
    assert audit.audited_changes.key?("depot_ids")
    changes = audit.audited_changes["depot_ids"]
    assert_includes changes.first, depot_to_remove.id
    assert_not_includes changes.last, depot_to_remove.id
  end

  test "does not audit depot_ids when unchanged" do
    cycle = delivery_cycles(:mondays)
    original_depot_ids = cycle.depot_ids.sort

    assert_no_difference(-> { Audit.where(auditable: cycle).count }) do
      cycle.update!(depot_ids: original_depot_ids)
    end
  end

  test "combines attribute, periods, and depot_ids changes into a single audit" do
    cycle = delivery_cycles(:mondays)
    period = cycle.periods.first
    new_depot = depots(:farm)

    # Ensure new_depot is not already associated
    cycle.depots.delete(new_depot)
    depot_ids_before_add = cycle.depot_ids.sort

    assert_difference(-> { Audit.where(auditable: cycle).count }, 1) do
      cycle.update!(
        absences_included_annually: 2,
        depot_ids: depot_ids_before_add + [ new_depot.id ],
        periods_attributes: [
          { id: period.id, from_fy_month: 1, to_fy_month: 6 },
          { from_fy_month: 7, to_fy_month: 12 }
        ]
      )
    end

    audit = cycle.audits.last
    # All changes in the same audit
    assert audit.audited_changes.key?("absences_included_annually"), "Expected absences_included_annually in audited changes"
    assert audit.audited_changes.key?("depot_ids"), "Expected depot_ids in audited changes"
    assert audit.audited_changes.key?("periods"), "Expected periods in audited changes"
  end
end

# frozen_string_literal: true

require "test_helper"

class Analytics::AbsencesTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "counts overlapping declared absences and members" do
    year = Analytics::Absences.new.for(2024)

    assert_equal 1, year.count
    assert_equal 1, year.member_count
  end

  test "counts an absence that spans two fiscal years in both years" do
    create_absence(
      member: members(:john),
      started_on: Date.new(2023, 12, 20),
      ended_on: Date.new(2024, 1, 10),
      admin: true)
    years = [ 2023, 2024, 2025 ].map { |year| Current.org.fiscal_year_for(year) }

    Analytics.stub(:fiscal_years, years) do
      assert_equal 1, Analytics::Absences.new.for(2023).count
      assert_equal 2, Analytics::Absences.new.for(2024).count
    end
  end

  test "computes YTD absent-basket rate for the current fiscal year" do
    travel_to "2025-04-15"
    year = Analytics::Absences.new.for(2025)

    assert year.in_progress?
    assert_equal 0, year.absent_rate
    assert_nil year.announcement_delay
  end

  test "computes median announcement delay from created_at to started_on" do
    absences(:jane_thursday_5).update_column(:created_at, Time.zone.parse("2024-04-17"))
    year = Analytics::Absences.new.for(2024)

    assert_equal 14, year.announcement_delay
  end

  test "clamps backdated announcement delays to zero" do
    absences(:jane_thursday_5).update_column(:created_at, Time.zone.parse("2024-05-10"))
    year = Analytics::Absences.new.for(2024)

    assert_equal 0, year.announcement_delay
  end

  test "hides included quota mix when nobody has leftover or used quota" do
    absences = Analytics::Absences.new
    year = absences.for(2024)

    assert_equal 0, year.declared_quota
    assert_equal 0, year.leftover_quota
    assert_not absences.included_quota?
    assert_not absences.charts.any? { |chart| chart.id == "included-quota" }
  end

  test "splits included quota into declared and unused leftover" do
    memberships(:john).update!(absences_included_annually: 1)
    absences = Analytics::Absences.new
    year = absences.for(2024)

    assert_equal 0, year.declared_quota
    assert_equal 1, year.leftover_quota
    assert absences.included_quota?
    assert absences.charts.any? { |chart| chart.id == "included-quota" }
  end

  test "counts a declared included absence as used quota, not leftover" do
    memberships(:john).update!(absences_included_annually: 1)
    basket = memberships(:john).baskets.second
    create_absence(
      member: members(:john),
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date + 1.day)
    year = Analytics::Absences.new.for(2024)

    assert_equal 1, year.declared_quota
    assert_equal 0, year.leftover_quota
  end

  test "counts unused included quota even when leftover baskets are still in the future" do
    travel_to "2025-04-15"
    memberships(:john_future).update!(absences_included_annually: 2)
    year = Analytics::Absences.new.for(2025)

    assert year.in_progress?
    assert_equal 0, year.declared_quota
    assert_equal 2, year.leftover_quota
  end

  test "hides included quota mix for unbilled extras when nobody has a quota" do
    org(absences_billed: false)
    baskets(:jane_5).update_columns(billable: false)
    absences = Analytics::Absences.new
    year = absences.for(2024)

    assert_equal 0, year.declared_quota
    assert_equal 0, year.leftover_quota
    assert_not absences.included_quota?
  end

  test "caps unbilled declared extras at each membership included quota" do
    org(absences_billed: false)
    memberships(:john).update!(absences_included_annually: 1)
    john = memberships(:john)
    create_absence(
      member: members(:john),
      started_on: john.baskets.second.delivery.date,
      ended_on: john.baskets.second.delivery.date + 1.day)
    create_absence(
      member: members(:john),
      started_on: john.baskets.third.delivery.date,
      ended_on: john.baskets.third.delivery.date + 1.day)
    baskets(:jane_5).update_columns(billable: false)
    year = Analytics::Absences.new.for(2024)

    assert_equal 1, year.declared_quota
    assert_equal 0, year.leftover_quota
  end

  test "does not steal leftover from one membership to cover extras on another" do
    org(absences_billed: false)
    memberships(:john).update!(absences_included_annually: 1)
    memberships(:jane).update!(absences_included_annually: 1)
    jane = memberships(:jane)
    create_absence(
      member: members(:jane),
      started_on: jane.baskets.third.delivery.date,
      ended_on: jane.baskets.third.delivery.date + 1.day)
    jane.baskets.absent.update_all(billable: false)
    year = Analytics::Absences.new.for(2024)

    assert_equal 1, year.declared_quota
    assert_equal 1, year.leftover_quota
  end
end

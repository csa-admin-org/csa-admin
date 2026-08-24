# frozen_string_literal: true

require "test_helper"

class Analytics::ActivitiesTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "sums demanded and accepted participations for a fiscal year" do
    year = Analytics::Activities.new.for(2024)

    assert_equal 4, year.count
    assert_equal 2, year.accepted
    assert_in_delta 50.0, year.fulfillment_rate, 0.01
  end

  test "splits accepted into participated and billed missing hours" do
    Invoice.create!(
      member: members(:jane),
      date: Date.new(2024, 12, 15),
      entity_type: "ActivityParticipation",
      missing_activity_participations_fiscal_year: 2024,
      missing_activity_participations_count: 1)
    year = Analytics::Activities.new.for(2024)

    assert_equal 1, year.billed_missing
    assert_equal 4, year.accepted
    assert_equal 3, year.participated
    assert Analytics::Activities.new.billed_missing?
  end

  test "computes YTD fulfillment rate for the current fiscal year" do
    year = Analytics::Activities.new.for(2025)

    assert year.in_progress?
    assert_in_delta 100.0, year.fulfillment_rate, 0.01
  end

  test "signup chart uses month labels and counts accepted participants" do
    ActivityParticipation.update_all(created_at: Time.zone.parse("2023-01-01"))
    activity_participations(:john_harvest).update_column(:created_at, Time.zone.parse("2024-03-15"))
    activity_participations(:jane_harvest).update_columns(
      created_at: Time.zone.parse("2024-06-01"),
      state: "rejected")
    panel = Analytics::Activities.new.charts.find { |chart| chart.id == "signups" }
    data = panel.config[:data][:datasets].find { |dataset| dataset[:label] == "2024" }[:data]

    assert_equal ("0".."12").to_a, panel.config.dig(:data, :labels)
    refute panel.config.dig(:options, :syncYear)
    assert_equal I18n.t("analytics.charts.signups"), panel.title
    assert_equal [ 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2 ], data
  end

  test "defaults to the last past year with demanded participations" do
    Membership.during_year(2024).update_all(activity_participations_demanded: 0)
    years = [ 2023, 2024, 2025 ].map { |year| Current.org.fiscal_year_for(year) }

    Analytics.stub(:fiscal_years, years) do
      assert_equal 2023, Analytics::Activities.new.default_year.fiscal_year.year
    end
  end
end

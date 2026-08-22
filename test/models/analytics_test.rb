# frozen_string_literal: true

require "test_helper"

class AnalyticsTest < ActiveSupport::TestCase
  test "fiscal years start at the first meaningful membership year" do
    travel_to "2025-01-15"

    assert_equal 2024, Analytics.first_meaningful_year.year
    assert_equal [ 2024, 2025 ], Analytics.fiscal_years.map(&:year)
  end

  test "skips tiny setup years that are small versus the peak season" do
    travel_to "2025-01-15"

    years = [ 2022, 2023, 2024, 2025 ].map { |year| Current.org.fiscal_year_for(year) }
    counts = { 2022 => 2, 2023 => 491, 2024 => 500, 2025 => 483 }

    Analytics.stub(:org_fiscal_years, years) do
      Analytics.stub(:membership_counts_by_year, ->(_years) { counts }) do
        assert_equal 2023, Analytics.first_meaningful_year.year
        assert_equal [ 2023, 2024, 2025 ], Analytics.fiscal_years.map(&:year)
      end
    end
  end

  test "excludes fiscal years that have not started yet" do
    travel_to "2025-01-15"

    years = [ 2024, 2025, 2026 ].map { |year| Current.org.fiscal_year_for(year) }
    Analytics.stub(:org_fiscal_years, years) do
      Analytics.stub(:first_meaningful_year, years.first) do
        assert_equal [ 2024, 2025 ], Analytics.fiscal_years.map(&:year)
      end
    end
  end

  test "fiscal years start at year_for of the earliest date" do
    org(fiscal_year_start_month: 4)
    travel_to "2018-06-15"

    Analytics.stub(:earliest_year, 2016) do
      assert_equal [ 2016, 2017, 2018 ], Analytics.send(:compute_org_fiscal_years).map(&:year)
    end
  end

  test "earliest year uses year_for of a delivery before the start month" do
    org(fiscal_year_start_month: 4)

    Delivery.stub(:minimum, Date.new(2017, 3, 31)) do
      assert_equal 2016, Analytics.send(:earliest_year)
    end
  end

  test "year_for uses the organization fiscal year start month" do
    org(fiscal_year_start_month: 4)

    assert_equal 2016, Analytics.year_for(Date.new(2017, 3, 31))
    assert_equal 2017, Analytics.year_for(Date.new(2017, 4, 1))
  end

  test "percentile interpolates between sorted values" do
    assert_nil Analytics.percentile([], 50)
    assert_equal 10, Analytics.percentile([ 10 ], 50)
    assert_equal 15, Analytics.percentile([ 10, 20 ], 50)
    assert_in_delta 19, Analytics.percentile([ 10, 20 ], 90), 0.01
  end

  test "lists pages that have a feature and volume" do
    travel_to "2025-01-15"

    assert_equal %i[memberships billing absences activities], analytics_pages
  end

  test "hides memberships when none exist" do
    travel_to "2025-01-15"

    Membership.stub(:exists?, false) do
      assert_equal %i[billing absences activities], analytics_pages
    end
  end

  test "hides absences when the feature is off" do
    travel_to "2025-01-15"
    org(features: Current.org.features - [ :absence ])

    assert_not_includes analytics_pages, :absences
  end

  test "includes shop once an order is invoiced" do
    travel_to "2025-01-15"
    create_shop_order.invoice!

    assert_includes analytics_pages, :shop
    assert_instance_of Analytics::Shop, Analytics.for(:shop)
  end

  test "hides shop when invoiced orders are outside the window" do
    travel_to "2025-01-15"
    create_shop_order(delivery: deliveries(:monday_past_1)).invoice!
    years = [ 2024, 2025 ].map { |year| Current.org.fiscal_year_for(year) }

    Analytics.stub(:fiscal_years, years) do
      assert_not_includes analytics_pages, :shop
    end
  end

  test "includes basket contents once a delivery is filled" do
    travel_to "2025-01-15"
    create_basket_content(unit: "pc", unit_price: 2)

    assert_includes analytics_pages, :basket_content
  end

  test "hides activities when demanded is zero in the window" do
    travel_to "2025-01-15"
    Membership.update_all(activity_participations_demanded: 0)

    assert_not_includes analytics_pages, :activities
  end

  private

  def analytics_pages
    cache = Current.analytics_cache
    cache.delete(:pages)
    cache.delete(:fiscal_years)
    cache.delete(:org_fiscal_years)
    Analytics::PAGES.each_key { |page| cache.delete(:"for_#{page}") }
    Analytics.pages
  end
end

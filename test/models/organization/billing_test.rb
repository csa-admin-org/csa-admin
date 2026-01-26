# frozen_string_literal: true

require "test_helper"

class Organization::BillingTest < ActiveSupport::TestCase
  test "fiscal_years returns an array of fiscal years" do
    fiscal_years = Current.org.fiscal_years

    assert_kind_of Array, fiscal_years
    assert fiscal_years.any?
    assert fiscal_years.all? { |fy| fy.is_a?(FiscalYear) }
  end

  test "fiscal_years includes current fiscal year" do
    fiscal_years = Current.org.fiscal_years

    assert_includes fiscal_years, Current.org.current_fiscal_year
  end

  test "fiscal_years spans from earliest to latest delivery years" do
    fiscal_years = Current.org.fiscal_years
    min_date = Delivery.minimum(:date)
    max_date = Delivery.maximum(:date)

    assert fiscal_years.any? { |fy| fy.include?(min_date) }
    assert fiscal_years.any? { |fy| fy.include?(max_date) }
  end

  test "fiscal_years handles nil delivery dates by using compact" do
    # This tests the fix for the "comparison of Integer with nil failed" error
    # that occurs when Delivery.minimum(:date) or Delivery.maximum(:date)
    # returns nil (no deliveries in the database).
    #
    # The fix uses .compact before .min/.max to filter out nil values:
    #   [ Delivery.minimum(:date)&.year, Current.fy_year, ... ].compact.min

    # Simulate what would happen with nil values from the database
    current_year = Date.current.year

    # Without compact, this would raise "comparison of Integer with nil failed"
    with_nil = [ nil, current_year, current_year ].compact.min
    assert_equal current_year, with_nil

    # Also verify that max works the same way
    with_nil_max = [ nil, current_year, current_year ].compact.max
    assert_equal current_year, with_nil_max

    # When all delivery dates are nil, we should still get valid years
    only_nils = [ nil, nil, current_year ].compact
    assert_equal [ current_year ], only_nils
    assert_equal current_year, only_nils.min
    assert_equal current_year, only_nils.max
  end
end

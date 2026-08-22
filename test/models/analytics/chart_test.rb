# frozen_string_literal: true

require "test_helper"

class Analytics::ChartTest < ActiveSupport::TestCase
  test "serializes share totals on stacked charts" do
    panel = chart.stacked_area(
      "depots", "Depots", "map",
      [ [ "A", [ 10 ] ], [ "B", [ 5 ] ] ],
      share_totals: [ 40 ])

    assert_equal [ 40 ], panel.config.dig(:options, :shareTotals)
  end

  test "signed rate lines leave the axis uncapped" do
    panel = chart.signed_rate_line(
      "content-price-gap", "Gap to planned price", "scale",
      [ [ "Small", [ -80.0 ] ] ])

    assert_nil panel.config.dig(:options, :scales, :y, :max)
    assert panel.config.dig(:options, :scales, :y, :ticks, :percentage)
  end

  test "does not interpolate missing years on line charts" do
    panel = chart.line(
      "prices", "Prices", "receipt-text",
      [ [ "Average", [ 10, nil, 12 ] ] ],
      currency: true)

    refute panel.config.dig(:data, :datasets, 0, :spanGaps)
  end

  test "omits share totals when the mix is complete" do
    panel = chart.stacked_area(
      "size-mix", "Size mix", "shopping-bag",
      [ [ "Small", [ 10 ] ], [ "Large", [ 5 ] ] ])

    assert_nil panel.config.dig(:options, :shareTotals)
  end

  private

  def chart
    year = Data.define(:fiscal_year).new(2024)
    page = Object.new
    page.define_singleton_method(:series) { [ year ] }
    page.define_singleton_method(:default_year_index) { 0 }
    page.define_singleton_method(:open_year_index) { nil }
    Analytics::Chart.new(page)
  end
end

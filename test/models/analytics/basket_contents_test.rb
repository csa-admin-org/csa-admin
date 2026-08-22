# frozen_string_literal: true

require "test_helper"

class Analytics::BasketContentsTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "counts filled past deliveries and product diversity" do
    create_basket_content(
      delivery: deliveries(:monday_1),
      unit: "pc",
      unit_price: 2)
    year = Analytics::BasketContents.new.for(2024)

    assert_equal 1, year.count
    assert year.unfilled_count.positive?
    assert_equal 1, year.product_count
    assert year.coverage_rate.positive?
    assert year.median_content_value.positive?
    assert Analytics::BasketContents.new.content_value?
  end

  test "tracks content value per basket size and top products" do
    create_basket_content(
      delivery: deliveries(:monday_1),
      unit: "pc",
      unit_price: 2)
    create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:carrots),
      unit: "kg",
      unit_price: 3)
    contents = Analytics::BasketContents.new
    year = contents.for(2024)

    assert year.size_values[small_id].positive?
    assert year.size_values[medium_id].positive?
    assert_equal 2, year.product_count
    assert contents.products?
    assert_equal 2, contents.products.size
    panel = contents.charts.find { |chart| chart.id == "top-products" }
    assert_equal I18n.t("analytics.charts.top_products"), panel.title
    assert_equal contents.series.map { |series_year| series_year.product_counts.values.sum },
      panel.config.dig(:options, :shareTotals)
  end

  test "excludes future deliveries from coverage" do
    create_basket_content(
      delivery: deliveries(:monday_future_1),
      unit: "pc",
      unit_price: 2)
    year = Analytics::BasketContents.new.for(2025)

    assert year.in_progress?
    assert_nil year.coverage_rate
    assert_equal 0, year.count
  end

  test "hides content value when deliveries have no unit prices" do
    create_basket_content(delivery: deliveries(:monday_1), unit: "pc")
    contents = Analytics::BasketContents.new

    assert_not contents.content_value?
    assert_not contents.price_gap?
  end

  test "tracks median content value gap versus the planned size price" do
    create_basket_content(
      delivery: deliveries(:monday_1),
      unit: "pc",
      unit_price: 2)
    contents = Analytics::BasketContents.new
    year = contents.for(2024)

    assert_in_delta(-80.0, year.size_price_gaps[small_id])
    assert_in_delta(-90.0, year.size_price_gaps[medium_id])
    assert contents.price_gap?
    assert contents.charts.any? { |chart| chart.id == "content-price-gap" }
  end

  test "applies the delivery size price percentage to the planned price" do
    deliveries(:monday_2).update_column(:basket_size_price_percentage, 50)
    create_basket_content(
      delivery: deliveries(:monday_2),
      unit: "pc",
      unit_price: 2,
      basket_size_ids_quantities: { medium_id => 1 })
    year = Analytics::BasketContents.new.for(2024)

    assert_in_delta(-80.0, year.size_price_gaps[medium_id])
  end

  test "page title follows the org basket terminology" do
    Current.org.update_column(:basket_i18n_scopes, Current.org.languages.index_with { "bag" })
    Current.org.reload

    assert_equal I18n.t("analytics.sections.basket_content/bag"), Analytics::BasketContents.title
  end

  test "caps products at the palette size" do
    contents = Analytics::BasketContents.new
    year = Object.new
    year.define_singleton_method(:product_counts) { (1..9).index_with { |i| i } }
    contents.stub(:series, [ year ]) do
      assert_equal 9, contents.send(:all_product_ids).size
      assert_equal "#{I18n.t("analytics.charts.top_products")} (#{I18n.t("analytics.top_n", count: Analytics::PALETTE_SIZE)})",
        contents.send(:top_products_title)
    end
  end
end

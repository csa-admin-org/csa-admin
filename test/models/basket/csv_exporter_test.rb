# frozen_string_literal: true

require "test_helper"

class Basket::CSVExporterTest < ActiveSupport::TestCase
  test "raises ArgumentError when neither delivery nor fiscal_year provided" do
    assert_raises(ArgumentError) do
      Basket::CSVExporter.new
    end
  end

  test "single delivery export includes member details columns" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    csv = CSV.parse(exporter.generate, headers: true)

    # Member detail columns (translated)
    assert_includes csv.headers, Basket.human_attribute_name(:name)
    assert_includes csv.headers, Basket.human_attribute_name(:emails)
    assert_includes csv.headers, Basket.human_attribute_name(:phones)
    assert_includes csv.headers, Basket.human_attribute_name(:street)
    assert_includes csv.headers, Basket.human_attribute_name(:zip)
    assert_includes csv.headers, Basket.human_attribute_name(:city)
    assert_includes csv.headers, Basket.human_attribute_name(:food_note)
    assert_includes csv.headers, Basket.human_attribute_name(:delivery_note)

    # Should NOT have delivery columns in single delivery mode
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_id)
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_date)
  end

  test "single delivery export filename includes delivery info" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    assert_match(/delivery-/, exporter.filename)
    assert_match(/20240401/, exporter.filename)
    assert_match(/\.csv$/, exporter.filename)
  end

  test "fiscal year export includes delivery columns" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    csv = CSV.parse(exporter.generate, headers: true)

    assert_includes csv.headers, Basket.human_attribute_name(:delivery_id)
    assert_includes csv.headers, Basket.human_attribute_name(:delivery_date)
  end

  test "fiscal year export excludes member details columns" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    csv = CSV.parse(exporter.generate, headers: true)

    refute_includes csv.headers, Basket.human_attribute_name(:name)
    refute_includes csv.headers, Basket.human_attribute_name(:emails)
    refute_includes csv.headers, Basket.human_attribute_name(:phones)
    refute_includes csv.headers, Basket.human_attribute_name(:street)
    refute_includes csv.headers, Basket.human_attribute_name(:food_note)
    refute_includes csv.headers, Basket.human_attribute_name(:delivery_note)
  end

  test "fiscal year export filename includes year" do
    fiscal_year = Current.org.fiscal_year_for(2024)
    exporter = Basket::CSVExporter.new(fiscal_year: fiscal_year)

    assert_match(/deliveries-/, exporter.filename)
    assert_match(/2024/, exporter.filename)
    assert_match(/\.csv$/, exporter.filename)
  end

  test "export includes common columns" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    exporter = Basket::CSVExporter.new(delivery: delivery)

    csv = CSV.parse(exporter.generate, headers: true)

    assert_includes csv.headers, Basket.human_attribute_name(:basket_id)
    assert_includes csv.headers, Basket.human_attribute_name(:membership_id)
    assert_includes csv.headers, Basket.human_attribute_name(:member_id)
    assert_includes csv.headers, Basket.human_attribute_name(:depot_id)
    assert_includes csv.headers, Basket.human_attribute_name(:depot)
    assert_includes csv.headers, Basket.human_attribute_name(:basket_size_id)
    assert_includes csv.headers, Basket.human_attribute_name(:quantity)
    assert_includes csv.headers, Basket.human_attribute_name(:state)
    assert_includes csv.headers, Basket.human_attribute_name(:description)
  end
end

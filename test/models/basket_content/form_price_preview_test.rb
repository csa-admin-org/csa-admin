# frozen_string_literal: true

require "test_helper"

class BasketContent::FormPricePreviewTest < ActiveSupport::TestCase
  def setup
    travel_to "2022-04-01"
  end

  test "returns basket counts without price data" do
    preview = build_preview(
      unit: nil,
      unit_price: nil,
      depot_ids: [ depots(:home).id, depots(:farm).id ])

    assert_equal 1, preview[:baskets_counts][small_id]
    assert_equal 1, preview[:baskets_counts][medium_id]
    assert_equal 0, preview[:total_product_value]
    assert_empty preview[:prices_data]
  end

  test "returns zero basket counts for explicit empty depot selection" do
    preview = build_preview(depot_ids_empty: "1")

    assert_equal 0, preview[:baskets_counts][small_id]
    assert_equal 0, preview[:baskets_counts][medium_id]
    assert_empty preview[:prices_data]
  end

  test "returns kg surplus without price data" do
    preview = build_preview(
      unit: "kg",
      unit_price: nil,
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      })

    assert_equal 750, preview[:total_quantity_surplus]
    assert_equal "g", preview[:total_quantity_surplus_unit]
    assert_equal 0, preview[:total_product_value]
    assert_empty preview[:prices_data]
  end

  test "returns prices and kg surplus" do
    preview = build_preview(
      unit: "kg",
      unit_price: "2",
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      })

    assert_equal 750, preview[:total_quantity_surplus]
    assert_equal "g", preview[:total_quantity_surplus_unit]
    assert_equal 2.5, preview[:total_product_value]
    assert_equal 1, preview[:prices_data][small_id][:baskets_count]
    assert_equal 1.0, preview[:prices_data][small_id][:product_price]
    assert_equal 1.0, preview[:prices_data][small_id][:total_value]
  end

  test "returns prices and piece surplus rounded to tens" do
    baskets(:bob_1).update_column(:quantity, 1)
    baskets(:john_1).update_column(:quantity, 1)
    baskets(:anna_1).update_column(:quantity, 1)

    preview = build_preview(
      unit: "pc",
      unit_price: "0.50",
      basket_size_ids_quantities: {
        small_id => 39,
        medium_id => 48,
        large_id => 40
      })

    assert_equal 3, preview[:total_quantity_surplus]
    assert_equal "pc", preview[:total_quantity_surplus_unit]
    assert_equal 63.5, preview[:total_product_value]
  end

  private

  def build_preview(**params)
    BasketContent::FormPricePreview.new(
      delivery: deliveries(:monday_1),
      params: {
        product_id: basket_content_products(:carrots).id
      }.merge(params)).to_h
  end
end

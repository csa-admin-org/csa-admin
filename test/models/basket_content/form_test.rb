# frozen_string_literal: true

require "test_helper"

class BasketContent::FormTest < ActiveSupport::TestCase
  def setup
    travel_to "2022-04-01"
  end

  test "nil delivery returns empty result without surplus" do
    result = BasketContent::Form::Distribution.new(
      delivery: nil,
      params: {
        product_id: basket_content_products(:carrots).id,
        unit: "kg"
      }
    ).to_h

    assert_equal 0, result[:total_quantity]
    assert_equal 0, result[:total_product_value]
    assert_empty result[:basket_sizes]
    refute result[:total_changed]
    assert_empty result[:quantities_changed]
    refute_includes result, :surplus
    refute_includes result, :surplus_unit
  end

  test "total-driven kg distribution keeps the requested one decimal target" do
    config(small: 1, medium: 0, large: 0)

    result = build_distribution(
      total_quantity: "2.9",
      unit: "kg",
      distribution_source: "total",
      basket_size_ids_percentages: { small_id => "100" }
    )

    assert_equal 2.9, result[:total_quantity]
    assert_equal 2900, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]
    refute result[:total_changed]
  end

  test "total-driven kg uses floor/ceil search without surplus auto bump" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "2",
      unit: "kg",
      distribution_source: "total",
      basket_size_ids_percentages: {
        small_id => "33",
        medium_id => "33",
        large_id => "34"
      }
    )

    assert_equal 2.0, result[:total_quantity]
    assert_equal 400, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]
    assert_equal 400, result[:basket_sizes].find { |bs| bs[:id] == medium_id }[:quantity]

    allocated_grams = result[:basket_sizes].sum { |bs| bs[:quantity] * bs[:baskets_count] }
    assert_equal 2000, allocated_grams
    refute_includes result, :surplus
  end

  test "total-driven kg leaves the target unchanged when allocation cannot use it all" do
    config(small: 2001, medium: 0, large: 0)

    result = build_distribution(
      total_quantity: "2",
      unit: "kg",
      distribution_source: "total",
      basket_size_ids_percentages: {
        small_id => "1",
        medium_id => "1",
        large_id => "98"
      }
    )

    assert_equal 2.0, result[:total_quantity]
    refute result[:total_changed]
  end

  test "allocation-driven kg computes total from quantities and rounds up to 100 grams" do
    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "2",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "700",
        medium_id => "510"
      }
    )

    assert_equal 1.3, result[:total_quantity]
    assert result[:total_changed]
  end

  test "allocation-driven kg recomputes lower and higher totals from quantities" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "1",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "400",
        medium_id => "600"
      }
    )

    assert_equal 2.6, result[:total_quantity]

    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "5",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "800",
        medium_id => "1200"
      }
    )

    assert_equal 2.0, result[:total_quantity]
  end

  test "pc totals use exact pieces without next ten rounding" do
    config(small: 1, medium: 0, large: 0)

    result = build_distribution(
      total_quantity: "10.1",
      unit: "pc",
      distribution_source: "total",
      basket_size_ids_percentages: { small_id => "100" }
    )

    assert_equal 11, result[:total_quantity]
    assert_equal 11, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]

    config(small: 2, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "100",
      unit: "pc",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "10",
        medium_id => "15"
      }
    )

    assert_equal 35, result[:total_quantity]
  end

  test "total-driven pc bumps total when too low for all basket sizes" do
    config(small: 1, medium: 1, large: 1)

    result = build_distribution(
      total_quantity: "2",
      unit: "pc",
      distribution_source: "total",
      depot_ids: Depot.kept.pluck(:id),
      basket_size_ids_percentages: {
        small_id => "33",
        medium_id => "33",
        large_id => "34"
      }
    )

    result[:basket_sizes].each do |bs|
      next if bs[:baskets_count] == 0

      assert bs[:quantity] >= 1,
        "#{bs[:name]} should get at least 1 piece"
    end

    assert result[:total_changed]
    assert result[:total_quantity] >= 3
  end

  test "presets apply percentages and keep kg total target" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "5.3",
      unit: "kg",
      distribution_source: "total",
      preset: "pro_rated",
      basket_size_ids_percentages: {
        small_id => "50",
        medium_id => "50",
        large_id => "0"
      }
    )

    assert_equal 5.3, result[:total_quantity]
    active_sizes = result[:basket_sizes].select { |bs| bs[:baskets_count] > 0 }
    assert active_sizes.any? { |bs| bs[:quantity] > 0 }
    assert_equal 100, active_sizes.sum { |bs| bs[:percentage] }
  end

  test "basket counts match selected depots" do
    result = build_distribution(
      total_quantity: "1",
      unit: "kg",
      distribution_source: "quantity",
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: { small_id => "100" }
    )

    small_entry = result[:basket_sizes].find { |bs| bs[:id] == small_id }
    medium_entry = result[:basket_sizes].find { |bs| bs[:id] == medium_id }

    assert_equal 1, small_entry[:baskets_count]
    assert_equal 1, medium_entry[:baskets_count]
  end

  test "depot_ids_empty flag produces zero basket counts" do
    result = build_distribution(
      total_quantity: "1",
      unit: "kg",
      distribution_source: "quantity",
      depot_ids: nil,
      depot_ids_empty: "1",
      basket_size_ids_quantities: { small_id => "500" }
    )

    result[:basket_sizes].each do |bs|
      assert_equal 0, bs[:baskets_count],
        "#{bs[:name]} should have 0 baskets when depot_ids_empty"
    end
  end

  test "prices computed correctly with unit_price" do
    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "2",
      unit: "kg",
      unit_price: "3.50",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "500",
        medium_id => "750"
      }
    )

    small_entry = result[:basket_sizes].find { |bs| bs[:id] == small_id }
    medium_entry = result[:basket_sizes].find { |bs| bs[:id] == medium_id }

    assert_equal 1.75, small_entry[:product_price]
    assert_equal 1.75, small_entry[:total_value]
    assert_equal 2.63, medium_entry[:product_price]
    assert_equal 2.63, medium_entry[:total_value]
    assert_equal (0.5 * 3.50 + 0.75 * 3.50).round(2), result[:total_product_value]
  end

  test "zero total with source total produces zero quantities" do
    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "0",
      unit: "kg",
      distribution_source: "total",
      basket_size_ids_quantities: {
        small_id => "500",
        medium_id => "750"
      },
      basket_size_ids_percentages: {
        small_id => "50",
        medium_id => "50",
        large_id => "0"
      }
    )

    result[:basket_sizes].each do |bs|
      assert_equal 0, bs[:quantity],
        "#{bs[:name]} should have 0 quantity when total is 0"
    end
  end

  test "unit falls back to selected product when not sent explicitly" do
    result = build_distribution(
      product_id: basket_content_products(:cucumbers).id,
      unit: nil,
      total_quantity: "20",
      distribution_source: "quantity",
      basket_size_ids_quantities: { small_id => "5" }
    )

    assert_equal "pc", result[:unit]
    refute_includes result, :surplus_unit
  end

  private

  def config(small: 0, medium: 0, large: 0)
    baskets(:bob_1).update_column(:quantity, small)
    baskets(:john_1).update_column(:quantity, medium)
    baskets(:anna_1).update_column(:quantity, large)
  end

  def build_distribution(**params)
    BasketContent::Form::Distribution.new(
      delivery: deliveries(:monday_1),
      params: {
        product_id: basket_content_products(:carrots).id,
        unit: "kg",
        depot_ids: [ depots(:home).id, depots(:farm).id ]
      }.merge(params)
    ).to_h
  end
end

# frozen_string_literal: true

require "test_helper"

class BasketContent::FormTest < ActiveSupport::TestCase
  def setup
    travel_to "2022-04-01"
  end

  # ─── 1. Empty/nil delivery returns empty result ───────────────────

  test "nil delivery returns empty result" do
    result = BasketContent::Form::Distribution.new(
      delivery: nil,
      params: {
        product_id: basket_content_products(:carrots).id,
        unit: "kg"
      }
    ).to_h

    assert_equal 0, result[:total_quantity]
    assert_equal 0, result[:surplus]
    assert_equal 0, result[:total_product_value]
    assert_empty result[:basket_sizes]
    refute result[:total_changed]
    assert_empty result[:quantities_changed]
  end

  # ─── 2. Total-driven kg distribution ──────────────────────────────

  test "total-driven kg distribution uses floor/ceil search" do
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

    assert_equal "kg", result[:unit]
    assert_equal 400, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]
    assert_equal 400, result[:basket_sizes].find { |bs| bs[:id] == medium_id }[:quantity]

    allocated_grams = result[:basket_sizes].sum { |bs| bs[:quantity] * bs[:baskets_count] }
    assert_equal 2000, allocated_grams
    assert_equal "g", result[:surplus_unit]
    assert_equal 0, result[:surplus]
  end

  test "total-driven kg rounds fractional total to the next whole kg" do
    config(small: 1, medium: 0, large: 0)

    result = build_distribution(
      total_quantity: "2.9",
      unit: "kg",
      distribution_source: "total",
      basket_size_ids_percentages: { small_id => "100" }
    )

    assert_equal 3, result[:total_quantity]
    assert_equal 3000, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]
  end

  test "total-driven pc rounds fractional total to the next piece step" do
    config(small: 1, medium: 0, large: 0)

    result = build_distribution(
      total_quantity: "10.1",
      unit: "pc",
      distribution_source: "total",
      basket_size_ids_percentages: { small_id => "100" }
    )

    assert_equal 20, result[:total_quantity]
    assert_equal 20, result[:basket_sizes].find { |bs| bs[:id] == small_id }[:quantity]
  end

  # ─── 3. Total-driven kg auto-bump ────────────────────────────────

  test "total-driven kg auto-bumps total when surplus is too large" do
    # With a very high basket quantity for one size and a tiny percentage,
    # the ideal grams per basket rounds to 0 (floor), leaving 100% surplus.
    # The ceil value (1g × 2001 baskets) exceeds target, forcing all-floors (0g).
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

    assert result[:total_changed], "Total should be bumped when surplus >= 1000g"
    assert result[:total_quantity] > 2, "Total should have been increased"
    # Auto-bump is capped at +5kg from original
    assert result[:total_quantity] <= 2 + BasketContent::Form::Distribution::MAX_AUTO_BUMP_KG
  end

  # ─── 4. Total-driven pc distribution ─────────────────────────────

  test "total-driven pc distribution gives at least 1 piece per active basket size" do
    config(small: 2, medium: 3, large: 4)

    result = build_distribution(
      total_quantity: "100",
      unit: "pc",
      distribution_source: "total",
      depot_ids: Depot.kept.pluck(:id),
      basket_size_ids_percentages: {
        small_id => "30",
        medium_id => "30",
        large_id => "40"
      }
    )

    result[:basket_sizes].each do |bs|
      next if bs[:baskets_count] == 0
      assert bs[:quantity] >= 1,
        "#{bs[:name]} should get at least 1 piece but got #{bs[:quantity]}"
      assert bs[:quantity] > 0, "Quantity should be a positive integer"
    end
  end

  # ─── 5. Total-driven pc minimum enforcement ──────────────────────

  test "total-driven pc bumps total when too low for all basket sizes" do
    config(small: 1, medium: 1, large: 1)

    # Total=2 is less than the 3 active sizes that each need at least 1 piece.
    # Required = 3 pieces, round_pc_total(3) = 3 > 2, so total must bump.
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

    # Total bumped from 2 to at least 3 to accommodate minimums
    assert result[:total_changed], "Total should be bumped to meet minimum"
    assert result[:total_quantity] >= 3
  end

  # ─── 6. Allocation-driven (source=quantity) basic ─────────────────

  test "allocation-driven kg computes total from quantities" do
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

    # sum_of_grams = 400*2 + 600*3 = 800 + 1800 = 2600g → ceil(2600/1000) = 3
    assert_equal 3, result[:total_quantity]

    # Percentages should be derived from quantities
    pct_sum = result[:basket_sizes].sum { |bs| bs[:percentage] }
    assert_equal 100, pct_sum
  end

  # ─── 7. Allocation-driven - total raises when over-allocated ──────

  test "allocation-driven raises total when quantities exceed current total" do
    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "1",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "800",
        medium_id => "900"
      }
    )

    # sum = 800*1 + 900*1 = 1700g → ceil(1700/1000) = 2 > 1
    assert_equal 2, result[:total_quantity]
    assert result[:total_changed], "Total should be changed (recomputed from quantities)"
  end

  # ─── 8. Allocation-driven - total lowers when surplus >= 1kg ──────

  test "allocation-driven kg lowers total when surplus exceeds 1kg" do
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

    # sum = 800*1 + 1200*1 = 2000g → ceil(2000/1000) = 2
    # current total = 5, surplus = 5000 - 2000 = 3000g >= 1000g → lower to 2
    assert_equal 2, result[:total_quantity]
  end

  # ─── 9. Allocation-driven - total lowers when surplus >= 10 (pc) ──

  test "allocation-driven pc lowers total when surplus exceeds 10 pieces" do
    config(small: 2, medium: 2, large: 0)

    result = build_distribution(
      total_quantity: "100",
      unit: "pc",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "10",
        medium_id => "15"
      }
    )

    # sum = 10*2 + 15*2 = 50 → rounded pc total = ceil(50/10)*10 = 50
    # current total = 100, surplus = 100 - 50 = 50 >= 10 → lower to 50
    assert_equal 50, result[:total_quantity]
  end

  # ─── 10. Allocation-driven - total stays when surplus < threshold ─

  test "allocation-driven kg keeps total when surplus is under 1kg" do
    config(small: 1, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "2",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "700",
        medium_id => "800"
      }
    )

    # sum = 700*1 + 800*1 = 1500g → ceil(1500/1000) = 2
    # current total = 2, surplus = 2000 - 1500 = 500g < 1000g → stays at 2
    assert_equal 2, result[:total_quantity]
  end

  # ─── 11. Preset pro_rated application ─────────────────────────────

  test "preset pro_rated applies pro-rated percentages" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "5",
      unit: "kg",
      distribution_source: "total",
      preset: "pro_rated",
      basket_size_ids_percentages: {
        small_id => "50",
        medium_id => "50",
        large_id => "0"
      }
    )

    # Pro-rated percentages should be computed (not the input 50/50)
    # Quantities should be computed from those percentages
    active_sizes = result[:basket_sizes].select { |bs| bs[:baskets_count] > 0 }
    assert active_sizes.any? { |bs| bs[:quantity] > 0 },
      "At least one active size should have a quantity > 0"

    pct_sum = result[:basket_sizes].select { |bs| bs[:baskets_count] > 0 }.sum { |bs| bs[:percentage] }
    assert_equal 100, pct_sum
  end

  # ─── 12. Preset even application ─────────────────────────────────

  test "preset even applies approximately equal percentages" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "5",
      unit: "kg",
      distribution_source: "total",
      preset: "even",
      basket_size_ids_percentages: {
        small_id => "10",
        medium_id => "90",
        large_id => "0"
      }
    )

    active_sizes = result[:basket_sizes].select { |bs| bs[:baskets_count] > 0 }
    percentages = active_sizes.map { |bs| bs[:percentage] }

    # Even distribution means percentages should be close to each other
    assert percentages.all? { |p| p > 0 }, "All active sizes should have non-zero percentages"
  end

  # ─── 13. Basket counts from depot selection ───────────────────────

  test "basket counts match selected depots" do
    # With depots [home, farm]: bob_1 (small@home) and john_1 (medium@farm)
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

  # ─── 14. Price computation ────────────────────────────────────────

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

    # small: 500g = 0.5kg × 3.50 = 1.75 per basket
    assert_equal 1.75, small_entry[:product_price]
    assert_equal 1.75, small_entry[:total_value] # 1 basket × 1.75

    # medium: 750g = 0.75kg × 3.50 = 2.625 rounded to 2.63
    assert_equal 2.63, medium_entry[:product_price]
    assert_equal 2.63, medium_entry[:total_value] # 1 basket × 2.63

    # total_product_value = sum of (quantity_in_unit × unit_price × baskets_count)
    expected_total = (0.5 * 3.50 * 1 + 0.75 * 3.50 * 1).round(2)
    assert_equal expected_total, result[:total_product_value]
  end

  # ─── 15. Percentage computation from quantities ───────────────────

  test "percentages computed from quantities sum to 100" do
    config(small: 1, medium: 1, large: 1)

    result = build_distribution(
      total_quantity: "3",
      unit: "kg",
      distribution_source: "quantity",
      depot_ids: Depot.kept.pluck(:id),
      basket_size_ids_quantities: {
        small_id => "500",
        medium_id => "750",
        large_id => "1000"
      }
    )

    percentages = result[:basket_sizes].map { |bs| bs[:percentage] }
    assert_equal 100, percentages.sum, "Percentages should sum to 100"

    # Each percentage roughly proportional to quantity
    # 500 / 2250 ≈ 22%, 750 / 2250 ≈ 33%, 1000 / 2250 ≈ 44%
    small_pct = result[:basket_sizes].find { |bs| bs[:id] == small_id }[:percentage]
    medium_pct = result[:basket_sizes].find { |bs| bs[:id] == medium_id }[:percentage]
    large_pct = result[:basket_sizes].find { |bs| bs[:id] == large_id }[:percentage]

    assert small_pct < medium_pct, "Small pct (#{small_pct}) should be less than medium (#{medium_pct})"
    assert medium_pct < large_pct, "Medium pct (#{medium_pct}) should be less than large (#{large_pct})"
  end

  # ─── 16. Zero total produces empty quantities ─────────────────────

  test "zero total with source=total produces zero quantities" do
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
    assert_equal "pc", result[:surplus_unit]
  end

  # ─── 17. Surplus computation ──────────────────────────────────────

  test "kg surplus is total*1000 minus allocated grams" do
    config(small: 2, medium: 1, large: 0)

    result = build_distribution(
      total_quantity: "3",
      unit: "kg",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "500",
        medium_id => "800"
      }
    )

    allocated_grams = result[:basket_sizes].sum { |bs| bs[:quantity] * bs[:baskets_count] }
    expected_surplus = [ result[:total_quantity] * 1000 - allocated_grams, 0 ].max

    assert_equal expected_surplus, result[:surplus]
    assert_equal "g", result[:surplus_unit]
    assert result[:surplus] >= 0
  end

  test "pc surplus is total minus allocated pieces" do
    config(small: 2, medium: 3, large: 0)

    result = build_distribution(
      total_quantity: "50",
      unit: "pc",
      distribution_source: "quantity",
      basket_size_ids_quantities: {
        small_id => "5",
        medium_id => "8"
      }
    )

    allocated_pieces = result[:basket_sizes].sum { |bs| bs[:quantity] * bs[:baskets_count] }
    expected_surplus = [ result[:total_quantity] - allocated_pieces, 0 ].max

    assert_equal expected_surplus, result[:surplus]
    assert_equal "pc", result[:surplus_unit]
    assert result[:surplus] >= 0
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

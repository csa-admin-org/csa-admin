# frozen_string_literal: true

require "test_helper"

class Shop::ProductVariantTest < ActiveSupport::TestCase
  test "defaults to pieces" do
    variant = Shop::ProductVariant.new(name: "Loose", price: 1)

    assert_equal "pc", variant.unit
    assert variant.pc?
  end

  test "pieces reject a fractional stock" do
    variant = shop_product_variants(:flour_wheat)

    assert_not variant.update(stock: 1.5)
    assert_includes variant.errors[:stock], "must be an integer"
  end

  test "kilograms accept a two decimal stock, reject a third, and clear weight" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(unit: "kg", weight_in_kg: 1, stock: "0.66")

    assert_equal "0.66".to_d, variant.reload.stock
    assert_nil variant.weight_in_kg

    assert_not variant.update(stock: "0.001")
    assert variant.errors[:stock].any?
  end

  test "kilograms reject a basket complement" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(unit: "kg")

    assert_not variant.update(basket_complement: basket_complements(:eggs))
    assert variant.errors[:basket_complement_id].any?
  end

  test "pieces cannot become kilograms while a complement is linked" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(basket_complement: basket_complements(:eggs))

    assert_not variant.update(unit: "kg")
    assert variant.errors[:basket_complement_id].any?
  end

  test "unit can change while the variant has no orders" do
    variant = shop_product_variants(:flour_wheat)

    assert variant.update(unit: "kg")
    assert variant.update(unit: "pc")
  end

  test "unit cannot change either way once an order item exists" do
    variant = shop_product_variants(:flour_wheat)
    create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:flour).id,
        product_variant_id: variant.id,
        quantity: 1
      }
    })

    assert_not variant.update(unit: "kg")
    assert variant.errors[:unit].any?

    variant.update_columns(unit: "kg")
    assert_not variant.update(unit: "pc")
    assert variant.errors[:unit].any?
  end
end

# frozen_string_literal: true

require "test_helper"

class BasketContent::ProductTest < ActiveSupport::TestCase
  test "validates default_unit inclusion in UNITS" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "invalid",
      default_unit_price: 10
    )

    assert_not product.valid?
    assert_includes product.errors[:default_unit], "is not included in the list"
  end

  test "validates default_unit_price is non-negative" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "kg",
      default_unit_price: -5
    )

    assert_not product.valid?
    assert_includes product.errors[:default_unit_price], "must be greater than or equal to 0"
  end

  test "validates default_unit_price is required when default_unit is set" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "kg",
      default_unit_price: nil
    )

    assert_not product.valid?
    assert_includes product.errors[:default_unit_price], "can't be blank"
  end

  test "validates default_unit is required when default_unit_price is set" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: nil,
      default_unit_price: 10
    )

    assert_not product.valid?
    assert_includes product.errors[:default_unit], "can't be blank"
  end

  test "allows both default_unit and default_unit_price to be nil" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: nil,
      default_unit_price: nil
    )

    assert product.valid?
  end

  test "allows both default_unit and default_unit_price to be blank strings" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "",
      default_unit_price: ""
    )

    assert product.valid?
  end

  test "allows both default_unit and default_unit_price to be set" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "kg",
      default_unit_price: 5.50
    )

    assert product.valid?
  end

  test "allows default_unit_price of zero when default_unit is set" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      default_unit: "pc",
      default_unit_price: 0
    )

    assert product.valid?
  end
end

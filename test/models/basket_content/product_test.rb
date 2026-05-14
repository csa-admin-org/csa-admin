# frozen_string_literal: true

require "test_helper"

class BasketContent::ProductTest < ActiveSupport::TestCase
  test "validates unit presence" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: nil
    )

    assert_not product.valid?
    assert_includes product.errors[:unit], "can't be blank"
  end

  test "validates unit inclusion in UNITS" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "invalid"
    )

    assert_not product.valid?
    assert_includes product.errors[:unit], "is not included in the list"
  end

  test "validates default_price is non-negative" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "kg",
      default_price: -5
    )

    assert_not product.valid?
    assert_includes product.errors[:default_price], "must be greater than or equal to 0"
  end

  test "allows default_price to be nil" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "kg",
      default_price: nil
    )

    assert product.valid?
  end

  test "allows default_price of zero" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "pc",
      default_price: 0
    )

    assert product.valid?
  end

  test "validates url format requires http or https" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "kg",
      url: "not-a-valid-url"
    )

    assert_not product.valid?
    assert_includes product.errors[:url], "is invalid"
  end

  test "allows valid https url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "kg",
      url: "https://www.example.com/path/to/page"
    )

    assert product.valid?
  end

  test "allows blank url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      unit: "kg",
      url: ""
    )

    assert product.valid?
  end

  test "name_with_unit includes unit label only when sibling exists" do
    product = basket_content_products(:carrots)
    # No sibling with same name, so no suffix
    assert_equal "Carrots", product.name_with_unit

    product = basket_content_products(:cucumbers)
    assert_equal "Cucumbers", product.name_with_unit

    # Create a sibling (same name, different unit)
    sibling = BasketContent::Product.create!(
      names: product[:names],
      unit: "kg"
    )
    product.reload
    assert_equal "Cucumbers (#{I18n.t('units.pc.short')})", product.name_with_unit
    assert_equal "Cucumbers (#{I18n.t('units.kg.short')})", sibling.name_with_unit
  end

  test "sync_latest_basket_content! updates price and quantities from latest" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_1),
      basket_size_ids_quantities: { small_id => 300, medium_id => 600 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 2.50)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 3.25)

    product.reload
    assert_equal BigDecimal("3.25"), product.default_price
    assert_equal({ small_id.to_s => 500, medium_id.to_s => 750 }, product.default_basket_quantities)
  end

  test "sync_latest_basket_content! uses delivery date order not creation order" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 3.25)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_1),
      basket_size_ids_quantities: { small_id => 300, medium_id => 600 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 2.50)

    product.reload
    # Should still reflect the later delivery (monday_2)
    assert_equal BigDecimal("3.25"), product.default_price
    assert_equal({ small_id.to_s => 500, medium_id.to_s => 750 }, product.default_basket_quantities)
  end

  test "sync_latest_basket_content! does not change product unit" do
    product = basket_content_products(:carrots)
    assert_equal "kg", product.unit

    create_basket_content(
      product: product,
      delivery: deliveries(:monday_1),
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 3.00)

    product.reload
    assert_equal "kg", product.unit
  end
end

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

  test "validates url format requires http or https" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: "not-a-valid-url"
    )

    assert_not product.valid?
    assert_includes product.errors[:url], "is invalid"
  end

  test "validates url format rejects ftp protocol" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: "ftp://example.com/file.pdf"
    )

    assert_not product.valid?
    assert_includes product.errors[:url], "is invalid"
  end

  test "allows valid http url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: "http://example.com/page"
    )

    assert product.valid?
  end

  test "allows valid https url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: "https://www.example.com/path/to/page"
    )

    assert product.valid?
  end

  test "allows blank url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: ""
    )

    assert product.valid?
  end

  test "allows nil url" do
    product = BasketContent::Product.new(
      names: { en: "Test Product" },
      url: nil
    )

    assert product.valid?
  end

  test "sync_latest_basket_content! updates defaults from latest basket content" do
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
    assert_equal "kg", product.default_unit
    assert_equal BigDecimal("3.25"), product.default_unit_price
    assert_equal({ small_id.to_s => 500, medium_id.to_s => 750 }, product.default_basket_quantities)
  end

  test "sync_latest_basket_content! uses delivery date order not creation order" do
    product = basket_content_products(:carrots)
    # Create content for a later delivery first
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 3.25)
    # Then create content for an earlier delivery
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_1),
      basket_size_ids_quantities: { small_id => 2, medium_id => 4 },
      depots: Depot.all,
      unit: "pc",
      unit_price: 1.00)

    product.reload
    # Should still reflect the later delivery (monday_2)
    assert_equal "kg", product.default_unit
    assert_equal BigDecimal("3.25"), product.default_unit_price
    assert_equal({ small_id.to_s => 500, medium_id.to_s => 750 }, product.default_basket_quantities)
  end

  test "default_basket_quantities stores display-ready values" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_1),
      basket_size_ids_quantities: { small_id => 500, medium_id => 750 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 3.00)

    product.reload
    # Stored as grams (display format), not raw kg decimals
    assert_equal({ small_id.to_s => 500, medium_id.to_s => 750 }, product.default_basket_quantities)
  end
end

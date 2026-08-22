# frozen_string_literal: true

require "test_helper"

class Analytics::ShopTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "counts invoiced shop orders on delivery fiscal year" do
    create_shop_order.invoice!
    year = Analytics::Shop.new.for(2024)

    assert_equal 1, year.count
    assert_equal 1, year.member_count
    assert year.amount.positive?
    assert_equal year.amount, year.average_amount
  end

  test "excludes future deliveries from shop volume" do
    create_shop_order.invoice!
    create_shop_order(delivery: deliveries(:thursday_future_1)).invoice!
    shop = Analytics::Shop.new

    assert_equal 1, shop.for(2024).count
    assert_equal 0, shop.for(2025).count
  end

  test "ignores pending shop orders" do
    create_shop_order
    year = Analytics::Shop.new.for(2024)

    assert_equal 0, year.count
    assert_empty Analytics::Shop.new
  end

  test "ranks top product variants by quantity" do
    create_shop_order(
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          quantity: 2
        },
        "1" => {
          product_id: shop_products(:flour).id,
          product_variant_id: shop_product_variants(:flour_wheat).id,
          quantity: 1
        }
      }).invoice!
    shop = Analytics::Shop.new
    year = shop.for(2024)
    oil_key = [ shop_products(:oil).id, shop_product_variants(:oil_500).id ]
    flour_key = [ shop_products(:flour).id, shop_product_variants(:flour_wheat).id ]

    assert_equal 2, year.variant_quantities[oil_key]
    assert_equal 1, year.variant_quantities[flour_key]
    assert shop.variants?
    assert_equal [ oil_key, flour_key ], shop.variants.keys
    panel = shop.charts.find { |chart| chart.id == "shop-products" }
    assert_equal I18n.t("analytics.charts.shop_products"), panel.title
    assert_equal shop.series.map { |series_year| series_year.variant_quantities.values.sum },
      panel.config.dig(:options, :shareTotals)
  end

  test "caps shop products at the palette size" do
    shop = Analytics::Shop.new
    year = Object.new
    year.define_singleton_method(:variant_quantities) {
      (1..9).to_h { |i| [ [ i, i ], i ] }
    }
    shop.stub(:series, [ year ]) do
      assert_equal 9, shop.send(:all_variant_keys).size
      assert_equal "#{I18n.t("analytics.charts.shop_products")} (#{I18n.t("analytics.top_n", count: Analytics::PALETTE_SIZE)})",
        shop.send(:shop_products_title)
    end
  end
end

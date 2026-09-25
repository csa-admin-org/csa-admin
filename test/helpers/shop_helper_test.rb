# frozen_string_literal: true

require "test_helper"

class ShopHelperTest < ActionView::TestCase
  include FormsHelper
  include MembersHelper

  test "variants collection labels product and variant and searches producer and tags" do
    product = shop_products(:bread)
    product.tags << Shop::Tag.create!(names: { "en" => "Bakery" }, emoji: "🍞")

    label, id, html = shop_order_variants_collection
      .then { |collection| option_rows(collection) }
      .find { |(_, variant_id, _)| variant_id == shop_product_variants(:bread_500).id }

    assert_equal shop_product_variants(:bread_500).id, id
    assert_equal "Bread > 500g", label
    assert_includes html.dig(:data, :search), "Farm"
    assert_includes html.dig(:data, :search), "Bakery"
    assert_includes html.dig(:data, :search), "🍞"
    assert_equal "5", html.dig(:data, :price)
  end

  test "variants collection pins recently used variants and does not duplicate them" do
    older = shop_order_items(:john_bread_500)
    older.update_columns(created_at: 2.days.ago, updated_at: 2.days.ago)
    newer = create_shop_order.items.first
    newer.update_columns(created_at: 1.hour.ago, updated_at: 1.hour.ago)

    recent, others = shop_order_variants_collection

    assert_equal I18n.t("active_admin.searchable_select.recent"), recent.first
    assert_equal [ newer.product_variant_id, older.product_variant_id ], recent.last.map(&:second)
    assert recent.last.all? { |_, _, html| html.dig(:data, :recent) }
    assert_not_includes others.last.map(&:second), newer.product_variant_id
    assert_not_includes others.last.map(&:second), older.product_variant_id
  end

  test "variants collection omits out of stock variants unless one is already selected" do
    sold_out = shop_product_variants(:oil_1000)
    sold_out.update!(stock: 0)

    ids = option_rows(shop_order_variants_collection).map(&:second)
    refute_includes ids, sold_out.id

    selected_ids = option_rows(shop_order_variants_collection(sold_out)).map(&:second)
    assert_includes selected_ids, sold_out.id
  end

  test "variants collection keeps a selected variant after its product is discarded" do
    variant = shop_product_variants(:oil_1000)
    variant.product.discard

    assert_includes option_rows(shop_order_variants_collection(variant)).map(&:second), variant.id
  end

  test "variants collection marks every option recent when the recent set covers the list" do
    Shop::ProductVariant.where.not(id: shop_product_variants(:bread_500).id).update_all(stock: 0)

    collection = shop_order_variants_collection
    rows = option_rows(collection)

    assert_equal [ shop_product_variants(:bread_500).id ], rows.map(&:second)
    assert rows.all? { |_, _, html| html.dig(:data, :recent) }
    assert_not_equal I18n.t("active_admin.searchable_select.recent"), collection.first&.first
  end

  private

  def option_rows(collection)
    return collection.flat_map(&:last) if collection.first&.last.is_a?(Array)

    collection
  end
end

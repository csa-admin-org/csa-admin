# frozen_string_literal: true

require "test_helper"

class BasketContentsHelperTest < ActionView::TestCase
  test "unit suffix helpers return per-size and total suffixes" do
    assert_equal "g", basket_content_unit_suffix("kg")
    assert_equal "kg", basket_content_total_unit_suffix("kg")
    pc_suffix = I18n.t("units.pc_quantity", quantity: "").strip
    assert_equal pc_suffix, basket_content_unit_suffix("pc")
    assert_equal pc_suffix, basket_content_total_unit_suffix("pc")
  end

  test "form percentages use saved quantities or pro-rated defaults" do
    new_content = BasketContent.new(unit: "kg")
    assert_equal new_content.basket_size_ids_percentages_pro_rated,
      basket_content_form_percentages(new_content)

    content = build_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg")
    assert_equal({ small_id => 40, medium_id => 60 }, basket_content_form_percentages(content))
  end

  test "products collection shows plain name without sibling" do
    product = basket_content_products(:carrots)

    name, _, _ = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    assert_equal "Carrots", name
  end

  test "products collection shows name with unit when sibling exists" do
    product = basket_content_products(:carrots)
    BasketContent::Product.create!(names: product[:names], unit: "pc")

    name, _, _ = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    assert_equal "Carrots (#{I18n.t('units.kg.short')})", name
  end

  test "products collection includes unit in data attributes" do
    product = basket_content_products(:carrots)

    _, _, options = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    assert_equal "kg", options[:data][:unit]
  end

  test "products collection embeds synced price and quantities" do
    product = basket_content_products(:carrots)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      depots: [ depots(:home), depots(:farm) ],
      unit: "kg",
      unit_price: 3.25)

    _, _, options = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    data = options[:data]

    assert_equal BigDecimal("3.25"), data[:latest_basket_content_unit_price]
    assert_equal({
      small_id.to_s => 500,
      medium_id.to_s => 750
    }, JSON.parse(data[:latest_basket_content_quantities]))
  end
end

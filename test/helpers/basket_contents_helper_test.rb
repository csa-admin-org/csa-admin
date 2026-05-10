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

  test "products collection embeds latest quantities" do
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
    unit_data = data[:latest_basket_content]["kg"]

    assert_equal "kg", data[:latest_basket_content_unit]
    assert_equal BigDecimal("3.25"), unit_data[:unit_price]
    assert_equal({
      small_id.to_s => 500,
      medium_id.to_s => 750
    }, unit_data[:basket_size_ids_quantities])
    assert_not unit_data.key?(:depot_ids)
  end

  test "products collection keeps default unit price with latest quantities" do
    product = basket_content_products(:carrots)
    product.update!(default_unit: "kg", default_unit_price: 4.50)
    create_basket_content(
      product: product,
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: {
        small_id => 250,
        medium_id => 500
      },
      depots: [ depots(:bakery) ],
      unit: "kg",
      unit_price: 3.25)

    _, _, options = basket_content_products_collection.find { |(_, id, _)| id == product.id }
    data = options[:data]
    unit_data = data[:latest_basket_content]["kg"]

    assert_equal "kg", data[:latest_basket_content_unit]
    assert_equal BigDecimal("4.5"), unit_data[:unit_price]
    assert_equal({
      small_id.to_s => 250,
      medium_id.to_s => 500
    }, unit_data[:basket_size_ids_quantities])
    assert_not unit_data.key?(:depot_ids)
  end
end

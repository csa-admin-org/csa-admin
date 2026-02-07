# frozen_string_literal: true

require "test_helper"

class Basket::ContentTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-04-01"
  end

  test "returns basket contents for the basket's delivery" do
    basket = baskets(:jane_1) # large basket, bakery depot, thursday_1
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")

    contents = basket.contents
    assert_equal 1, contents.size
    assert_equal "Carrots", contents.first.product.name
  end

  test "filters by depot" do
    basket = baskets(:jane_1) # bakery depot

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { large_id => 100 },
      depots: [ depots(:farm) ],
      quantity: 3,
      unit: "pc")

    contents = basket.contents
    assert_equal [ "Carrots" ], contents.map { |bc| bc.product.name }
  end

  test "filters by basket size" do
    basket = baskets(:jane_1) # large basket

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { small_id => 100 },
      depots: Depot.all,
      quantity: 100,
      unit: "pc")

    contents = basket.contents
    assert_equal [ "Carrots" ], contents.map { |bc| bc.product.name }
  end

  test "sorts by product name" do
    basket = baskets(:jane_1)

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 3,
      unit: "pc")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")

    contents = basket.contents
    assert_equal [ "Carrots", "Cucumbers" ], contents.map { |bc| bc.product.name }
  end

  test "returns empty array when no basket contents exist" do
    basket = baskets(:jane_1)

    assert_empty basket.contents
  end

  test "returns empty array when no contents match depot and size" do
    basket = baskets(:jane_1) # large basket, bakery depot

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { small_id => 100 },
      depots: [ depots(:farm) ],
      quantity: 100,
      unit: "pc")

    assert_empty basket.contents
  end

  test "does not include contents from other deliveries" do
    basket = baskets(:jane_1) # thursday_1

    create_basket_content(
      delivery: deliveries(:thursday_2),
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")

    assert_empty basket.contents
  end

  test "excludes contents with zero quantity for the basket size" do
    basket = baskets(:jane_1) # large basket, bakery depot, thursday_1

    bc = create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_percentages: { large_id => 100 },
      depots: Depot.all,
      quantity: 20,
      unit: "kg")

    # Simulate an edge case where quantity ends up as zero for this basket size
    # (e.g. data changed after the BasketContent was saved)
    idx = bc.basket_size_ids.index(basket.basket_size_id)
    quantities = bc.basket_quantities.dup
    quantities[idx] = 0
    bc.update_columns(basket_quantities: quantities)

    assert_empty basket.contents
  end
end

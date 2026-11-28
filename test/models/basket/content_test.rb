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
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
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
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
      unit: "kg")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { large_id => 3 },
      depots: [ depots(:farm) ],
      unit: "pc")

    contents = basket.contents
    assert_equal [ "Carrots" ], contents.map { |bc| bc.product.name }
  end

  test "filters by basket size" do
    basket = baskets(:jane_1) # large basket

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
      unit: "kg")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { small_id => 100 },
      depots: Depot.all,
      unit: "pc")

    contents = basket.contents
    assert_equal [ "Carrots" ], contents.map { |bc| bc.product.name }
  end

  test "sorts by product name" do
    basket = baskets(:jane_1)

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { large_id => 3 },
      depots: Depot.all,
      unit: "pc")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
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
      basket_size_ids_quantities: { small_id => 100 },
      depots: [ depots(:farm) ],
      unit: "pc")

    assert_empty basket.contents
  end

  test "does not include contents from other deliveries" do
    basket = baskets(:jane_1) # thursday_1

    create_basket_content(
      delivery: deliveries(:thursday_2),
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
      unit: "kg")

    assert_empty basket.contents
  end

  test "excludes contents with zero quantity for the basket size" do
    basket = baskets(:jane_1) # large basket, bakery depot, thursday_1

    bc = create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 20000 },
      depots: Depot.all,
      unit: "kg")

    # Simulate an edge case where quantity ends up as zero for this basket size
    # (e.g. data changed after the BasketContent was saved)
    bc.update_columns(basket_quantities: { basket.basket_size_id.to_s => 0 })

    assert_empty basket.contents
  end

  test "returns matching contents for a visible basket" do
    travel_to "2024-04-05"
    enable_member_basket_contents
    basket = baskets(:jane_1)

    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { large_id => 3 },
      depots: Depot.all,
      unit: "pc")
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")

    contents = Basket.contents_by_id([ basket ])[basket.id]

    assert_equal [ "Carrots", "Cucumbers" ], contents.map { |content| content.product.name }
  end

  test "returns no contents for a zero-quantity basket" do
    travel_to "2024-04-05"
    enable_member_basket_contents
    basket = baskets(:jane_1)
    basket.update_columns(quantity: 0)
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")

    assert_not_predicate basket, :empty?
    assert_nil Basket.contents_by_id([ basket ])[basket.id]
  end

  test "returns no contents for an absent basket" do
    travel_to "2024-05-03"
    enable_member_basket_contents
    basket = baskets(:jane_5)
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")

    assert_predicate basket, :absent?
    assert basket.quantity.positive?
    assert_nil Basket.contents_by_id([ basket ])[basket.id]
  end

  test "returns no contents for a shifted basket" do
    travel_to "2024-04-05"
    enable_member_basket_contents
    basket = baskets(:jane_1)
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")
    BasketShift.insert_all!([ {
      membership_id: basket.membership_id,
      source_delivery_id: basket.delivery_id,
      target_delivery_id: baskets(:jane_8).delivery_id,
      quantities: {},
      created_at: Time.current,
      updated_at: Time.current
    } ])
    basket.reload

    assert_predicate basket, :shifted?
    assert_not_predicate basket, :absent?
    assert basket.quantity.positive?
    assert_nil Basket.contents_by_id([ basket ])[basket.id]
  end

  test "returns no contents before the visibility window" do
    travel_to "2024-04-03 11:00"
    enable_member_basket_contents
    basket = baskets(:jane_1)
    create_basket_content(
      delivery: basket.delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: Depot.all,
      unit: "kg")

    assert_nil Basket.contents_by_id([ basket ])[basket.id]
  end

  test "excludes contents for another depot or with no quantity for the basket size" do
    travel_to "2024-04-02"
    enable_member_basket_contents
    anna = baskets(:anna_1) # large, bakery, monday_1
    bob = baskets(:bob_1) # small, home, monday_1
    create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { large_id => 1000 },
      depots: [ depots(:bakery) ],
      unit: "kg")
    create_basket_content(
      delivery: deliveries(:monday_1),
      product: basket_content_products(:cucumbers),
      basket_size_ids_quantities: { small_id => 2 },
      depots: [ depots(:home) ],
      unit: "pc")
    apples = BasketContent::Product.create!(names: { "en" => "Apples" }, unit: "pc")
    zero = create_basket_content(
      delivery: deliveries(:monday_1),
      product: apples,
      basket_size_ids_quantities: { large_id => 1 },
      depots: [ depots(:bakery) ],
      unit: "pc")
    zero.update_columns(basket_quantities: { large_id.to_s => 0 })

    contents = Basket.contents_by_id([ anna, bob ])

    assert_equal [ "Carrots" ], contents[anna.id].map { |content| content.product.name }
    assert_equal [ "Cucumbers" ], contents[bob.id].map { |content| content.product.name }
  end

  private

  def enable_member_basket_contents
    org(
      features: Current.org.features | [ :basket_content ],
      basket_content_member_visible: true,
      basket_content_member_visible_hours_before: 12)
  end
end

# frozen_string_literal: true

require "test_helper"

class BasketContentTest < ActiveSupport::TestCase
  def setup
    travel_to "2022-04-01"
  end

  def config(small: 0, medium: 0, large: 0)
    baskets(:bob_1).update_column(:quantity, small)
    baskets(:john_1).update_column(:quantity, medium)
    baskets(:anna_1).update_column(:quantity, large)
  end

  def build_basket_content(attrs)
    BasketContent.new({
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      quantity: 100
    }.merge(attrs))
  end

  def create_basket_content(attrs)
    build_basket_content(attrs).tap(&:save!)
  end

  test "validates quantity presence" do
    basket_content = build_basket_content(quantity: nil)
    assert_not basket_content.valid?
    assert_includes basket_content.errors[:quantity], "can't be blank"

    basket_content = build_basket_content(quantity: 0)
    assert_not basket_content.valid?
    assert_includes basket_content.errors[:quantity], "Insufficient"
  end

  test "validates percentages" do
    basket_content = build_basket_content(
      basket_size_ids_percentages: {
        small_id => 99
      })
    assert_not basket_content.valid?
    assert_includes basket_content.errors[:basket_percentages], "is invalid"
  end

  test "validates enough quantity" do
    config(small: 100, medium: 0)
    basket_content = build_basket_content(
      basket_size_ids_percentages: { small_id => 100 },
      quantity: 99,
      unit: "pc")
    assert_not basket_content.valid?
    assert_includes basket_content.errors[:quantity], "Insufficient"
  end

  test "validates enough quantity with miss piece" do
    config(small: 100, medium: 0)
    basket_content = build_basket_content(
      basket_size_ids_quantities: { small_id => 1 },
      quantity: 99,
      unit: "pc")

    assert_not basket_content.valid?
    assert_includes basket_content.errors[:quantity], "Insufficient (missing 1pc)"
  end

  test "set automatic mode by default" do
    config(small: 1, medium: 1)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 50,
        medium_id => 50
      },
      quantity: 150,
      unit: "pc")

    assert_equal "automatic", basket_content.distribution_mode
  end

  test "set manual mode when quantities present" do
    config(small: 1, medium: 1)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 50,
        medium_id => 50
      },
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      quantity: 150,
      unit: "pc")

    assert_equal "manual", basket_content.distribution_mode
  end

  test "splits pieces to both baskets" do
    config(small: 100, medium: 50)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      quantity: 150,
      unit: "pc")

    assert_equal [ 1, 1 ], basket_content.basket_quantities
    assert_equal 0, basket_content.surplus_quantity
  end

  test "splits pieces with more to big baskets" do
    config(small: 100, medium: 50)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      quantity: 200,
      unit: "pc")

    assert_equal [ 1, 2 ], basket_content.basket_quantities
    assert_equal 0, basket_content.surplus_quantity
  end

  test "gives all pieces to small baskets" do
    config(small: 100, medium: 50)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 100,
        medium_id => 0
      },
      quantity: 200,
      unit: "pc")

    assert_equal [ 2 ], basket_content.basket_quantities
    assert_nil basket_content.basket_quantity(BasketSize.new(id: medium_id))
    assert_equal 0, basket_content.surplus_quantity
  end

  test "splits kilogram to both baskets" do
    config(small: 131, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 41,
        medium_id => 59
      },
      quantity: 83,
      unit: "kg")

    assert_equal [ 0.48, 0.693 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 0.02, basket_content.surplus_quantity.to_f
  end

  test "splits kilogram to both baskets (2)" do
    config(small: 131, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 41,
        medium_id => 59
      },
      quantity: 100,
      unit: "kg")

    assert_equal [ 0.579, 0.832 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 0.02, basket_content.surplus_quantity.to_f
  end

  test "splits kilogram to both baskets (3)" do
    config(small: 151, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 41,
        medium_id => 59
      },
      quantity: 34,
      unit: "kg")

    assert_equal [ 0.176, 0.255 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 0.03, basket_content.surplus_quantity.to_f
  end

  test "splits kilogram equally between both baskets" do
    config(small: 131, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 50,
        medium_id => 50
      },
      quantity: 320,
      unit: "kg")

    assert_equal [ 2, 2 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 0, basket_content.surplus_quantity.to_f
  end

  test "gives all kilogram to big baskets" do
    config(small: 131, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 0,
        medium_id => 100
      },
      quantity: 83,
      unit: "kg")

    assert_equal [ 2.862 ], basket_content.basket_quantities.map(&:to_f)
    assert_nil basket_content.basket_quantity(BasketSize.new(id: small_id))
    assert_equal 0, basket_content.surplus_quantity.to_f
  end

  test "with 3 basket sizes" do
    config(small: 100, medium: 50, large: 20)
    basket_content = create_basket_content(
      basket_size_ids_percentages: {
        small_id => 23,
        medium_id => 33,
        large_id => 44
      },
      quantity: 100,
      unit: "kg")

    assert_equal [ 0.476, 0.684, 0.91 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 0, basket_content.surplus_quantity.to_f
  end

  test "gives all kilogram to big baskets with quantities" do
    config(small: 131, medium: 29)
    basket_content = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 0,
        medium_id => 2500
      },
      quantity: 83,
      unit: "kg")

    assert_equal [ 2.5 ], basket_content.basket_quantities.map(&:to_f)
    assert_nil basket_content.basket_quantity(BasketSize.new(id: small_id))
    assert_equal 10.5, basket_content.surplus_quantity.to_f
  end

  test "with 3 basket sizes with quantities" do
    config(small: 100, medium: 50, large: 20)
    basket_content = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 600,
        large_id => 900
      },
      quantity: 100,
      unit: "kg")

    assert_equal [ 0.5, 0.6, 0.9 ], basket_content.basket_quantities.map(&:to_f)
    assert_equal 2.0, basket_content.surplus_quantity.to_f
  end

  test "Delivery#update_basket_content_avg_prices! with all depots content" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    assert_changes -> { delivery.reload.basket_content_avg_prices }, from: {}, to: { small_id.to_s => "78.0", medium_id.to_s => "122.0" } do
      create_basket_content(
        basket_size_ids_percentages: {
          small_id => 40,
          medium_id => 60
        },
        delivery: delivery,
        quantity: 100,
        unit: "pc",
        unit_price: 2)
    end

    assert_equal({
      small_id => { delivery_cycles(:mondays) => 68 },
      medium_id => { delivery_cycles(:mondays) => 102 },
      large_id => { delivery_cycles(:mondays) => 0 }
    }, delivery.basket_content_yearly_price_diffs)

    assert_equal({
      basket_sizes(:small) => {
        depots(:farm) => 78.0,
        depots(:home) => 78.0,
        depots(:bakery) => 78.0
      },
      basket_sizes(:medium) => {
        depots(:farm) => 122,
        depots(:home) => 122,
        depots(:bakery) => 122
      },
      basket_sizes(:large) => {}
    }, delivery.basket_content_prices)
  end

  test "Delivery#update_basket_content_avg_prices! with different depots content" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    create_basket_content(
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      delivery: delivery,
      quantity: 100,
      unit: "pc",
      unit_price: 2,
      depots: [ depots(:home) ])

    assert_equal({
      small_id.to_s => "200.0"
    }, delivery.basket_content_avg_prices)
    assert_equal({
      basket_sizes(:small) => {
        depots(:home) => 200
      },
      basket_sizes(:medium) => {},
      basket_sizes(:large) => {}
    }, delivery.basket_content_prices)
  end

  test "Delivery#update_basket_content_avg_prices! with all in one basket_size" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    create_basket_content(
      basket_size_ids_percentages: {
        small_id => 0,
        medium_id => 100
      },
      delivery: delivery,
      quantity: 100,
      unit: "pc",
      unit_price: 2)

    assert_equal({
      medium_id.to_s => "200.0"
    }, delivery.basket_content_avg_prices)
    assert_equal({
      basket_sizes(:small) => {},
      basket_sizes(:medium) => {
        depots(:farm) => 200,
        depots(:home) => 200,
        depots(:bakery) => 200
      },
      basket_sizes(:large) => {}
    }, delivery.basket_content_prices)
  end

  test "Delivery#update_basket_content_avg_prices! with other delivery basket content" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)
    other_delivery = deliveries(:monday_2)

    create_basket_content(
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      delivery: delivery,
      quantity: 100,
      unit: "pc",
      unit_price: 2)
    create_basket_content(
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      delivery: other_delivery,
      quantity: 100,
      unit: "kg",
      unit_price: 1)

    assert_equal({
      medium_id.to_s => "100.0"
    }, other_delivery.basket_content_avg_prices)
    assert_equal({
      small_id.to_s => "78.0",
      medium_id.to_s => "122.0"
    }, delivery.basket_content_avg_prices)
    assert_not_equal other_delivery.basket_content_yearly_price_diffs, delivery.basket_content_yearly_price_diffs
    assert_equal({
      small_id => { delivery_cycles(:mondays) => 68 },
      medium_id => { delivery_cycles(:mondays) => 182 },
      large_id => { delivery_cycles(:mondays) => 0 }
    }, other_delivery.basket_content_yearly_price_diffs)
    assert_equal({
      small_id => { delivery_cycles(:mondays) => 68 },
      medium_id => { delivery_cycles(:mondays) => 102 },
      large_id => { delivery_cycles(:mondays) => 0 }
    }, delivery.basket_content_yearly_price_diffs)
  end

  test "duplicate_all copies all basket content from one delivery to another" do
    config(small: 1, medium: 1)
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: from_delivery,
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      quantity: 100,
      unit: "kg",
      unit_price: 1
    )
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      quantity: 150,
      unit: "pc")

    assert_difference -> { to_delivery.basket_contents.count }, 2 do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end

    assert_equal({
      "basket_size_ids" => [ small_id, medium_id ],
      "basket_percentages" => [ 40, 60 ],
      "quantity" => 100,
      "unit" => "kg",
      "unit_price" => 1
    }, to_delivery.basket_contents.first.attributes.slice(*%w[
      basket_size_ids
      basket_percentages
      quantity
      unit
      unit_price
    ]))
    assert_equal({
      "basket_size_ids" => [ small_id, medium_id ],
      "basket_quantities" => [ 75, 75 ],
      "quantity" => 150,
      "unit" => "pc"
    }, to_delivery.basket_contents.last.attributes.slice(*%w[
      basket_size_ids
      basket_quantities
      quantity
      unit
    ]))
  end

  test "duplicate_all does nothing when deliveries have no contents" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    assert_no_difference -> { to_delivery.basket_contents.count } do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end
  end

  test "duplicate_all does nothing when target delivery already has contents" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      delivery: from_delivery,
      basket_size_ids_percentages: {
        small_id => 40,
        medium_id => 60
      },
      quantity: 100,
      unit: "kg",
      unit_price: 1)
    create_basket_content(
      delivery: to_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      quantity: 150,
      unit: "pc")

    assert_no_difference -> { to_delivery.basket_contents.count } do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end
  end
end

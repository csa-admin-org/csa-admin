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

  test "allows empty basket_quantities" do
    bc = BasketContent.new(
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      unit: "pc")
    assert bc.valid?
  end

  test "validates basket_quantities values are positive" do
    bc = build_basket_content(
      basket_size_ids_quantities: {
        small_id => -1,
        medium_id => 1
      },
      unit: "pc")

    assert_not bc.valid?
    assert_includes bc.errors[:basket_quantities], "is invalid"
  end

  test "validates basket_quantities keys are paid basket sizes" do
    bc = BasketContent.new(
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_1),
      depots: Depot.all,
      unit: "pc",
      basket_quantities: { (BasketSize.maximum(:id) + 1).to_s => 1 })

    assert_not bc.valid?
    assert_includes bc.errors[:basket_quantities], "is invalid"
  end

  test "stores quantities as hash via setter (kg)" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg")

    assert_equal({ small_id.to_s => 0.5, medium_id.to_s => 0.75 }, bc.basket_quantities)
    assert_equal 0.5, bc.basket_quantity(basket_sizes(:small))
    assert_equal 0.75, bc.basket_quantity(basket_sizes(:medium))
  end

  test "stores quantities as hash via setter (pc)" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 2,
        medium_id => 3
      },
      unit: "pc")

    assert_equal({ small_id.to_s => 2, medium_id.to_s => 3 }, bc.basket_quantities)
    assert_equal 2, bc.basket_quantity(basket_sizes(:small))
    assert_equal 3, bc.basket_quantity(basket_sizes(:medium))
  end

  test "zero quantities are excluded from hash" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 0,
        medium_id => 2500
      },
      unit: "kg")

    assert_equal [ medium_id ], bc.basket_size_ids
    assert_equal 2.5, bc.basket_quantity(basket_sizes(:medium))
    assert_equal 0, bc.basket_quantity(basket_sizes(:small))
  end

  test "computes basket_size_ids from hash keys" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 600
      },
      unit: "kg")

    assert_equal [ small_id, medium_id ].sort, bc.basket_size_ids.sort
  end

  test "computes quantity (total) from basket quantities and counts" do
    config(small: 100, medium: 50)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 600
      },
      unit: "kg")

    # total = 0.5 * 100 + 0.6 * 50 = 50 + 30 = 80
    assert_equal 80.0, bc.quantity
  end

  test "computes display total quantity for kg rounded up to 100 grams" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg")

    assert_equal 1.25, bc.exact_quantity
    assert_equal 1.3, bc.total_quantity
  end

  test "computes exact display total quantity for pieces" do
    config(small: 1, medium: 1, large: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 39,
        medium_id => 48,
        large_id => 40
      },
      unit: "pc")

    assert_equal 127, bc.exact_quantity
    assert_equal 127, bc.total_quantity
  end

  test "keeps exact 100 gram kg totals unchanged" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 500
      },
      unit: "kg")

    assert_equal 1, bc.exact_quantity
    assert_equal 1.0, bc.total_quantity
  end

  test "does not round exact kg totals up due to floating point precision" do
    config(small: 100)
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 70 },
      unit: "kg")

    assert_equal 7, bc.exact_quantity
    assert_equal 7.0, bc.total_quantity
  end

  test "rounds fractional kg totals up to the next 100 grams" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 710
      },
      unit: "kg")

    assert_equal 1.21, bc.exact_quantity
    assert_equal 1.3, bc.total_quantity
  end

  test "computes baskets_count from delivery baskets" do
    config(small: 5, medium: 3)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 100,
        medium_id => 200
      },
      unit: "kg")

    assert_equal 5, bc.baskets_count(basket_sizes(:small))
    assert_equal 3, bc.baskets_count(basket_sizes(:medium))
  end

  test "baskets_count returns preloaded counts for all sizes" do
    bc = build_basket_content(
      basket_size_ids_quantities: { small_id => 100 },
      unit: "pc")
    bc.baskets_counts_hash = {
      small_id => 5,
      medium_id => 3
    }

    assert_equal 5, bc.baskets_count(basket_sizes(:small))
    assert_equal 3, bc.baskets_count(basket_sizes(:medium))
  end

  test "computes basket_percentage from relative quantities" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 600,
        large_id => 900
      },
      unit: "kg")

    assert_equal 25, bc.basket_percentage(basket_sizes(:small))
    assert_equal 30, bc.basket_percentage(basket_sizes(:medium))
    assert_equal 45, bc.basket_percentage(basket_sizes(:large))
  end

  test "basket_quantity returns 0 for unknown basket_size" do
    config(small: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 100 },
      unit: "pc")

    assert_equal 0, bc.basket_quantity(BasketSize.new(id: 999))
  end

  test "price_for returns quantity times unit_price when depot matches" do
    config(small: 1, medium: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 2)

    assert_equal 1.0, bc.price_for(basket_sizes(:small), depots(:farm))
    assert_equal 1.5, bc.price_for(basket_sizes(:medium), depots(:farm))
  end

  test "price_for returns nil when depot not included" do
    config(small: 1)
    bc = create_basket_content(
      basket_size_ids_quantities: { small_id => 500 },
      depots: [ depots(:farm) ],
      unit: "kg",
      unit_price: 2)

    assert_nil bc.price_for(basket_sizes(:small), depots(:home))
  end

  test "Delivery#update_basket_content_avg_prices! with all depots content" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    # small gets 39pc, medium gets 61pc → small price = 39*2=78, medium = 61*2=122
    assert_changes -> { delivery.reload.basket_content_avg_prices }, from: {}, to: { small_id.to_s => "78.0", medium_id.to_s => "122.0" } do
      create_basket_content(
        basket_size_ids_quantities: {
          small_id => 39,
          medium_id => 61
        },
        delivery: delivery,
        unit: "pc",
        unit_price: 2)
    end

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
      }
    }, delivery.basket_content_prices)
  end

  test "Delivery#update_basket_content_avg_prices! with different depots content" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    create_basket_content(
      basket_size_ids_quantities: {
        small_id => 100
      },
      delivery: delivery,
      unit: "pc",
      unit_price: 2,
      depots: [ depots(:home) ])

    assert_equal({
      small_id.to_s => "200.0"
    }, delivery.reload.basket_content_avg_prices)
    assert_equal({
      basket_sizes(:small) => {
        depots(:home) => 200
      }
    }, delivery.basket_content_prices)
  end

  test "Delivery#update_basket_content_avg_prices! with all in one basket_size" do
    config(small: 1, medium: 1)
    delivery = deliveries(:monday_1)

    create_basket_content(
      basket_size_ids_quantities: {
        medium_id => 100
      },
      delivery: delivery,
      unit: "pc",
      unit_price: 2)

    assert_equal({
      medium_id.to_s => "200.0"
    }, delivery.reload.basket_content_avg_prices)
    assert_equal({
      basket_sizes(:medium) => {
        depots(:farm) => 200,
        depots(:home) => 200,
        depots(:bakery) => 200
      }
    }, delivery.basket_content_prices)
  end

  test "moving basket content refreshes both deliveries stored prices" do
    source = deliveries(:monday_1)
    destination = deliveries(:monday_2)
    baskets(:john_1).update_column(:quantity, 1)
    baskets(:john_2).update_column(:quantity, 1)
    content = create_basket_content(
      basket_size_ids_quantities: { medium_id => 100 },
      delivery: source,
      depots: [ depots(:farm) ],
      unit: "pc",
      unit_price: 2)
    expected_avg_prices = { medium_id.to_s => "200.0" }
    expected_depot_ranges = {
      medium_id.to_s => { depots(:farm).id.to_s => "200.0" }
    }

    assert_equal expected_avg_prices, source.reload.basket_content_avg_prices
    assert_equal expected_depot_ranges, source.basket_content_depot_price_ranges

    content.update!(delivery: destination)

    assert_equal({}, source.reload.basket_content_avg_prices)
    assert_equal({}, source.basket_content_depot_price_ranges)
    assert_equal expected_avg_prices, destination.reload.basket_content_avg_prices
    assert_equal expected_depot_ranges, destination.basket_content_depot_price_ranges
  end

  test "destroying basket content clears its delivery stored prices" do
    config(medium: 1)
    delivery = deliveries(:monday_1)
    content = create_basket_content(
      basket_size_ids_quantities: { medium_id => 100 },
      delivery: delivery,
      depots: [ depots(:farm) ],
      unit: "pc",
      unit_price: 2)

    assert_not_empty delivery.reload.basket_content_avg_prices
    assert_not_empty delivery.basket_content_depot_price_ranges

    content.destroy!

    assert_empty delivery.reload.basket_content_avg_prices
    assert_empty delivery.basket_content_depot_price_ranges
  end

  test "destroying delivery with basket content succeeds" do
    delivery = Delivery.create!(date: Date.new(2022, 7, 1))
    create_basket_content(
      basket_size_ids_quantities: { medium_id => 100 },
      delivery: delivery,
      depots: [ depots(:farm) ],
      unit: "pc",
      unit_price: 2)

    assert_difference [ -> { Delivery.count }, -> { BasketContent.count } ], -1 do
      delivery.destroy!
    end
  end

  test "duplicate_all copies all basket content from one delivery to another" do
    config(small: 1, medium: 1)
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 1)
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      unit: "pc")

    assert_difference -> { to_delivery.basket_contents.count }, 2 do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end

    copied_kg = to_delivery.basket_contents.find_by(product: basket_content_products(:carrots))
    assert_equal({ small_id.to_s => 0.5, medium_id.to_s => 0.75 }, copied_kg.basket_quantities)
    assert_equal "kg", copied_kg.unit
    assert_equal 1, copied_kg.unit_price

    copied_pc = to_delivery.basket_contents.find_by(product: basket_content_products(:cucumbers))
    assert_equal({ small_id.to_s => 75, medium_id.to_s => 75 }, copied_pc.basket_quantities)
    assert_equal "pc", copied_pc.unit
  end

  test "duplicate_all does nothing when deliveries have no contents" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    assert_no_difference -> { to_delivery.basket_contents.count } do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end
  end

  test "duplicate_all copies missing contents when target delivery already has other contents" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 1)
    existing_content = create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: to_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      unit: "pc")

    assert_difference -> { to_delivery.basket_contents.count }, 1 do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end

    assert_equal existing_content, to_delivery.basket_contents.find_by(product: basket_content_products(:cucumbers))
    copied = to_delivery.basket_contents.find_by(product: basket_content_products(:carrots))
    assert_equal({ small_id.to_s => 0.5, medium_id.to_s => 0.75 }, copied.basket_quantities)
  end

  test "duplicate_all skips contents whose product already exists on target delivery" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg",
      unit_price: 1)
    existing_content = create_basket_content(
      product: basket_content_products(:carrots),
      delivery: to_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      unit: "pc")

    assert_no_difference -> { to_delivery.basket_contents.count } do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end
    assert_equal [ existing_content ], to_delivery.basket_contents.where(product: basket_content_products(:carrots)).to_a
  end

  test "duplicate_all skips existing products and copies missing products" do
    from_delivery = deliveries(:monday_1)
    to_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: from_delivery,
      basket_size_ids_quantities: {
        small_id => 75,
        medium_id => 75
      },
      unit: "pc")
    existing_content = create_basket_content(
      product: basket_content_products(:carrots),
      delivery: to_delivery,
      basket_size_ids_quantities: {
        medium_id => 75
      },
      unit: "pc")

    assert_difference -> { to_delivery.basket_contents.count }, 1 do
      BasketContent.duplicate_all(from_delivery.id, to_delivery.id)
    end

    assert_equal [ existing_content ], to_delivery.basket_contents.where(product: basket_content_products(:carrots)).to_a
    copied = to_delivery.basket_contents.find_by(product: basket_content_products(:cucumbers))
    assert_equal({ small_id.to_s => 75, medium_id.to_s => 75 }, copied.basket_quantities)
  end

  test "coming_deliveries_missing_contents_from includes empty and partial targets only" do
    source_delivery = deliveries(:monday_1)
    empty_delivery = deliveries(:monday_2)
    partial_delivery = deliveries(:monday_3)
    full_delivery = deliveries(:monday_4)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: source_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: source_delivery,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc")
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: partial_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: full_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: full_delivery,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc")

    deliveries = BasketContent.coming_deliveries_missing_contents_from(source_delivery)

    assert_includes deliveries, empty_delivery
    assert_includes deliveries, partial_delivery
    assert_not_includes deliveries, full_delivery
    assert_not_includes deliveries, source_delivery
  end

  test "coming_deliveries_missing_contents_from returns no deliveries when source has no contents" do
    assert_empty BasketContent.coming_deliveries_missing_contents_from(deliveries(:monday_1))
  end

  test "filled_deliveries_with_contents_missing_from includes only sources that can add contents" do
    to_delivery = deliveries(:monday_1)
    missing_source_delivery = deliveries(:monday_2)
    covered_source_delivery = deliveries(:monday_3)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: to_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: missing_source_delivery,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc")
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: covered_source_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")

    deliveries = BasketContent.filled_deliveries_with_contents_missing_from(to_delivery)

    assert_includes deliveries, missing_source_delivery
    assert_not_includes deliveries, covered_source_delivery
    assert_not_includes deliveries, to_delivery
  end

  test "filled_deliveries_with_contents_missing_from returns all filled sources when target is empty" do
    to_delivery = deliveries(:monday_1)
    source_delivery = deliveries(:monday_2)

    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: source_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")

    deliveries = BasketContent.filled_deliveries_with_contents_missing_from(to_delivery)

    assert_includes deliveries, source_delivery
    assert_not_includes deliveries, to_delivery
  end

  test "coming_deliveries_missing_contents_from does not query per target delivery" do
    source_delivery = deliveries(:monday_1)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: source_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: source_delivery,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc")
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_2),
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: deliveries(:monday_3),
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: deliveries(:monday_3),
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc")

    queries = collect_sql_queries {
      result = BasketContent.coming_deliveries_missing_contents_from(source_delivery).to_a
      assert_includes result, deliveries(:monday_2)
      assert_not_includes result, deliveries(:monday_3)
    }

    assert_no_per_row_basket_content_queries queries
    assert_operator queries.size, :<=, 3
  end

  test "filled_deliveries_with_contents_missing_from does not query per source delivery" do
    to_delivery = deliveries(:monday_1)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: to_delivery,
      basket_size_ids_quantities: { small_id => 100 },
      unit: "kg")
    (2..10).each do |i|
      create_basket_content(
        product: basket_content_products(:cucumbers),
        delivery: deliveries(:"monday_#{i}"),
        basket_size_ids_quantities: { small_id => 1 },
        unit: "pc")
    end

    queries = collect_sql_queries {
      result = BasketContent.filled_deliveries_with_contents_missing_from(to_delivery).to_a
      assert_equal 9, result.size
    }

    assert_no_per_row_basket_content_queries queries
    assert_operator queries.size, :<=, 3
  end

  private

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def assert_no_per_row_basket_content_queries(queries)
    per_row = queries.select { |sql|
      sql.match?(/SELECT 1 AS one FROM ["`]?basket_contents/i)
    }
    assert_empty per_row, "expected set-based queries, got: #{per_row.join("\n")}"
  end
end

# frozen_string_literal: true

require "test_helper"

class BasketCountsTest < ActiveSupport::TestCase
  test "sum_shop_orders only counts orders for the selected depots" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)

    create_shop_order(
      member: members(:bob),
      delivery: delivery,
      depot: depots(:farm))

    create_shop_order(
      member: members(:anna),
      delivery: delivery,
      depot: depots(:home))

    assert_equal 1, BasketCounts.new(delivery, [ farm_id ]).sum_shop_orders
    assert_equal 1, BasketCounts.new(delivery, [ home_id ]).sum_shop_orders
    assert_equal 0, BasketCounts.new(delivery, [ bakery_id ]).sum_shop_orders
    assert_equal 2, BasketCounts.new(delivery, [ farm_id, home_id ]).sum_shop_orders
  end

  test "delivery absent basket counts include depots with only absent baskets" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)

    baskets(:anna_1).update_column(:state, "absent")
    delivery.reload

    assert_equal 1, delivery.basket_counts(scope: :absent).all.sum(&:count)
  end

  test "delivery counts exclude absent baskets and their complements by default" do
    delivery = absent_basket_with_complement

    assert_equal 2, delivery.basket_counts.sum
    assert_nil delivery.basket_counts.all.find { |count| count.depot_id == depots(:bakery).id }
    assert_nil cheese_count(delivery)

    assert_equal 2, delivery.basket_counts(scope: :absent).sum
    assert_equal 3, delivery.basket_complement_counts(scope: :absent).sum(&:count)
  end

  test "delivery counts include absent baskets and their complements when enabled" do
    Current.org.update!(delivery_basket_counts_include_absences: true)
    delivery = absent_basket_with_complement

    assert_equal 4, delivery.basket_counts.sum
    assert_equal 2, delivery.basket_counts.all.find { |count| count.depot_id == depots(:bakery).id }.count
    assert_equal 3, cheese_count(delivery)
    assert_equal 2, delivery.basket_counts(scope: :absent).sum
  end

  test "complement totals are whole numbers" do
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    count = delivery.basket_complement_counts.find { |c| c.title == basket_complements(:bread) }

    assert_instance_of Integer, count.shop_orders_count
    assert_instance_of Integer, count.count
    assert_equal 1, count.count
  end

  test "the absence counts setting does nothing while the absence feature is off" do
    Current.org.update!(
      delivery_basket_counts_include_absences: true,
      features: Current.org.features - [ :absence ])
    delivery = absent_basket_with_complement

    assert_equal :active, Current.org.delivery_basket_count_scope
    assert_equal 2, delivery.basket_counts.sum
    assert_nil cheese_count(delivery)
  end

  private

  def absent_basket_with_complement
    travel_to "2024-04-01"
    delivery = deliveries(:monday_1)
    complement = basket_complements(:cheese)
    delivery.basket_complements << complement
    baskets(:anna_1).update!(
      quantity: 2,
      baskets_basket_complements_attributes: {
        "0" => { basket_complement_id: complement.id, quantity: 3 }
      })
    baskets(:anna_1).update_column(:state, "absent")
    delivery.reload
  end

  def cheese_count(delivery)
    delivery.basket_complement_counts.find { |count| count.title == basket_complements(:cheese) }&.count
  end
end

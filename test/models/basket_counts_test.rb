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
end

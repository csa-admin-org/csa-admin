# frozen_string_literal: true

require "test_helper"

class Shop::SpecialDeliveryTest < ActiveSupport::TestCase
  test "shop_closing_at" do
    delivery = shop_special_deliveries(:wednesday) # 2024-04-05
    delivery.update!(
      open: false,
      open_delay_in_days: nil,
      open_last_day_end_time: nil)

    travel_to "2024-01-01"
    assert_nil delivery.shop_closing_at
    assert_not delivery.shop_open?

    delivery.update!(open: true)
    assert_equal Time.zone.parse("2024-04-05 23:59:59"), delivery.shop_closing_at

    delivery.update!(open_delay_in_days: 4)
    assert_equal Time.zone.parse("2024-04-01 23:59:59"), delivery.shop_closing_at

    delivery.update!(open_last_day_end_time: "12:00:00")
    assert_equal Time.zone.parse("2024-04-01 12:00:00"), delivery.shop_closing_at

    travel_to "2024-04-01 12:00:00"
    assert delivery.shop_open?

    travel_to "2024-04-01 12:00:01"
    assert_not delivery.shop_open?
  end

  test "opening by depot" do
    travel_to "2024-01-01"
    delivery = shop_special_deliveries(:wednesday)

    assert delivery.shop_open?
    assert delivery.shop_open?(depot_id: farm_id)

    delivery.update!(available_for_depot_ids: [ home_id, bakery_id ])
    assert_equal [ home_id, bakery_id ], delivery.available_for_depot_ids

    assert_not delivery.shop_open?(depot_id: farm_id)
    assert delivery.shop_open?(depot_id: home_id)
    assert delivery.shop_open?(depot_id: bakery_id)
  end

  test "update_shop_products_count" do
    delivery = shop_special_deliveries(:wednesday)
    assert_equal 2, delivery.shop_products_count

    delivery.products << shop_products(:bread)
    delivery.save!
    assert_equal 3, delivery.shop_products_count
  end
end

# frozen_string_literal: true

require "test_helper"
require "shared/bulk_dates_insert"

class DeliveryTest < ActiveSupport::TestCase
  include Shared::BulkDatesInsert

  test "validates bulk inserts" do
    delivery = Delivery.create(
      bulk_dates_starts_on: Date.today,
      bulk_dates_wdays: [ 1 ],
      date: Date.today)

    assert_not delivery.valid?(:bulk_dates_starts_on)
    assert_not delivery.valid?(:bulk_dates_wdays)
  end

  test "bulk inserts with basket_complements" do
    travel_to "2020-01-01"
    bread = basket_complements(:bread)

    assert_difference "Delivery.count", 2 do
      Delivery.create(
        bulk_dates_starts_on: "2020-01-01",
        bulk_dates_ends_on: "2020-02-01",
        bulk_dates_weeks_frequency: 2,
        bulk_dates_wdays: [ 1 ],
        basket_complements: [ bread ])
    end

    assert_equal [ [ bread ], [ bread ] ], Delivery.first(2).map(&:basket_complements)
  end

  test "adds basket_complement on subscribed baskets" do
    travel_to "2024-01-01"
    bread = basket_complements(:bread)
    eggs = basket_complements(:eggs)

    membership = memberships(:john)
    membership.update!(subscribed_basket_complements: [ bread, eggs ])

    delivery = membership.deliveries.first
    delivery.update! basket_complements: [ eggs ]

    basket = membership.baskets.first
    assert_equal [ eggs ], basket.complements
    assert_equal eggs.price, basket.complements_price

    delivery.update! basket_complements: [ bread, eggs ]

    basket = membership.baskets.first
    assert_equal [ eggs, bread ], basket.complements
    assert_equal bread.price + eggs.price, basket.complements_price
  end

  test "removes basket_complement on subscribed baskets" do
    travel_to "2024-01-01"
    bread = basket_complements(:bread)

    membership = memberships(:jane)

    basket = membership.baskets.first
    assert_equal [ bread ], basket.complements

    delivery = membership.deliveries.first
    delivery.update! basket_complement_ids: []

    basket = membership.baskets.first
    assert_equal [], basket.complements
    assert_equal 0, basket.complements_price
  end

  test "updates all fiscal year delivery numbers" do
    travel_to "2024-01-01"
    first = deliveries(:monday_1)
    last = deliveries(:thursday_10)
    assert_equal 1, first.number
    assert_equal 20, last.number

    delivery = Delivery.create!(date: "2024-01-02")
    assert_equal 1, delivery.reload.number
    assert_equal 2, first.reload.number
    assert_equal 21, last.reload.number

    delivery.update! date: first.date + 1.day
    assert_equal 1, first.reload.number
    assert_equal 2, delivery.reload.number
    assert_equal 21, last.reload.number
  end

  test "update membership when date created" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_1)

    assert_difference -> { membership.baskets.count } do
      assert_difference -> { membership.reload.price }, basket.basket_price do
        Delivery.create!(date: "2024-06-10")
        perform_enqueued_jobs
      end
    end
  end

  test "update membership when date updated" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_1)
    delivery = deliveries(:monday_1)

    assert_difference -> { membership.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -basket.basket_price do
        delivery.update!(date: delivery.date + 1.day)
        perform_enqueued_jobs
      end
    end
  end

  test "update membership when date removed" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_1)

    assert_difference -> { membership.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -basket.basket_price do
        membership.deliveries.first.destroy!
        perform_enqueued_jobs
      end
    end
  end

  test "flags basket when creating them" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    absence = membership.member.absences.create!(
      started_on: "2024-06-05",
      ended_on: "2024-06-15")

    Delivery.create!(date: "2024-06-10")
    perform_enqueued_jobs

    basket = membership.baskets.last
    assert_equal "absent", basket.state
    assert_equal absence, basket.absence
  end

  test "reset delivery_cycle cache after date change" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2024" => 10, "2025" => 0 }, to: { "2024" => 11, "2025" => 0 } do
      Delivery.create!(date: "2024-06-10")
    end

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2024" => 11, "2025" => 0 }, to: { "2024" => 10, "2025" => 0 } do
      cycle.deliveries(2024).last.update!(date: "2024-06-11")
    end

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2024" => 10, "2025" => 0 }, to: { "2024" => 9, "2025" => 0 } do
      cycle.deliveries(2024).first.destroy!
    end
  end

  #
  # Shop
  #
  test "#shop_open is true by default" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    assert delivery.shop_open?

    delivery.update!(shop_open: false)
    assert_not delivery.shop_open?
  end

  test "when Organization#shop_delivery_open_delay_in_days is set" do
    Current.org.update!(shop_delivery_open_delay_in_days: 2)
    delivery = deliveries(:monday_1)

    travel_to "2024-03-30 23:59:59" do
      assert delivery.shop_open?
    end
    travel_to "2024-03-31" do
      assert_not delivery.shop_open?
    end
  end

  test "when Organization#shop_delivery_open_last_day_end_time is set" do
    Current.org.update!(shop_delivery_open_last_day_end_time: "12:00")
    delivery = deliveries(:monday_1)

    travel_to "2024-04-01 11:59" do
      assert delivery.shop_open?
    end
    travel_to "2024-04-01 12:00:01" do
      assert_not delivery.shop_open?
    end
  end

  test "when both Organization#shop_delivery_open_delay_in_days and Organization#shop_delivery_open_last_day_end_time are set" do
    Current.org.update!(
      shop_delivery_open_delay_in_days: 1,
      shop_delivery_open_last_day_end_time: "12:30")
    delivery = deliveries(:monday_1)

    travel_to "2024-03-31 12:30" do
      assert delivery.shop_open?
    end
    travel_to "2024-03-31 12:30:01" do
      assert_not delivery.shop_open?
    end
  end
end

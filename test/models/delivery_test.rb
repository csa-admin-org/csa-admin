# frozen_string_literal: true

require "test_helper"
require "shared/bulk_dates_insert"

class DeliveryTest < ActiveSupport::TestCase
  include Shared::BulkDatesInsert

  test "validates bulk inserts" do
    delivery = Delivery.create(
      bulk_dates_starts_on: Date.current,
      bulk_dates_wdays: [ 1 ],
      date: Date.current)

    assert_not delivery.valid?(:bulk_dates_starts_on)
    assert_not delivery.valid?(:bulk_dates_wdays)
  end

  test "validates date not in a fiscal year too far in the future" do
    travel_to "2025-05-01"

    # Current fiscal year (2025) is always allowed
    delivery = Delivery.new(date: "2025-12-31")
    assert delivery.valid?
    assert_empty delivery.errors[:date]

    # Next fiscal year (2026) starts Jan 1, 2026, exactly 8 months away → allowed
    delivery = Delivery.new(date: "2026-01-01")
    assert delivery.valid?
    assert_empty delivery.errors[:date]

    delivery = Delivery.new(date: "2026-12-31")
    assert delivery.valid?
    assert_empty delivery.errors[:date]

    # FY 2027 starts Jan 1, 2027, more than 8 months away → blocked
    delivery = Delivery.new(date: "2027-01-01")
    assert_not delivery.valid?
    assert_includes delivery.errors[:date], I18n.t("errors.messages.fiscal_year_too_far_in_future")
  end

  test "validates date one day before 8 months boundary blocks next fiscal year" do
    travel_to "2025-04-30"

    # FY 2026 starts Jan 1, 2026, which is more than 8 months away → blocked
    delivery = Delivery.new(date: "2026-01-01")
    assert_not delivery.valid?
    assert_includes delivery.errors[:date], I18n.t("errors.messages.fiscal_year_too_far_in_future")
  end

  test "validates date not in a fiscal year too far in the future with April fiscal year" do
    org(fiscal_year_start_month: 4)
    travel_to "2025-08-01"

    # Current FY (Apr 2025 - Mar 2026) → allowed
    delivery = Delivery.new(date: "2026-03-31")
    assert delivery.valid?
    assert_empty delivery.errors[:date]

    # Next FY starts Apr 1, 2026, exactly 8 months away → allowed
    delivery = Delivery.new(date: "2026-04-01")
    assert delivery.valid?
    assert_empty delivery.errors[:date]

    # FY after next starts Apr 1, 2027, more than 8 months away → blocked
    delivery = Delivery.new(date: "2027-04-01")
    assert_not delivery.valid?
    assert_includes delivery.errors[:date], I18n.t("errors.messages.fiscal_year_too_far_in_future")
  end

  test "validates date exactly 8 months before fiscal year start is allowed" do
    travel_to "2026-05-01"

    delivery = Delivery.new(date: "2027-01-01")
    assert delivery.valid?
    assert_empty delivery.errors[:date]
  end

  test "validates bulk_dates_starts_on not in a fiscal year too far in the future" do
    travel_to "2025-04-30"

    delivery = Delivery.new(
      bulk_dates_starts_on: "2027-01-01",
      bulk_dates_ends_on: "2027-02-01",
      bulk_dates_weeks_frequency: 1,
      bulk_dates_wdays: [ 1 ])

    assert_not delivery.valid?
    assert_includes delivery.errors[:bulk_dates_starts_on], I18n.t("errors.messages.fiscal_year_too_far_in_future")
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
    perform_enqueued_jobs do
      delivery.update! basket_complements: [ eggs ]
    end

    basket = membership.baskets.first
    assert_equal [ eggs ], basket.complements
    assert_equal eggs.price, basket.complements_price

    perform_enqueued_jobs do
      delivery.update! basket_complements: [ bread, eggs ]
    end

    basket = membership.baskets.first
    # Bread comes before Eggs alphabetically
    assert_equal [ bread, eggs ], basket.complements
    assert_equal bread.price + eggs.price, basket.complements_price
  end

  test "removes basket_complement on subscribed baskets" do
    travel_to "2024-01-01"
    bread = basket_complements(:bread)

    membership = memberships(:jane)

    basket = membership.baskets.first
    assert_equal [ bread ], basket.complements

    delivery = membership.deliveries.first
    perform_enqueued_jobs do
      delivery.update! basket_complement_ids: []
    end

    basket = membership.baskets.first
    assert_empty basket.complements
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
      assert_difference -> { membership.reload.price }, basket.basket_size_price do
        Delivery.create!(date: "2024-06-10")
        perform_enqueued_jobs
      end
    end
  end

  test "update membership when date updated" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    basket = baskets(:john_1)
    delivery = deliveries(:monday_2)

    assert_difference -> { membership.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -basket.basket_size_price do
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
      assert_difference -> { membership.reload.price }, -basket.basket_size_price do
        membership.deliveries.second.destroy!
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

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2023" => 10, "2024" => 10, "2025" => 10 }, to: { "2023" => 10, "2024" => 11, "2025" => 10 } do
      Delivery.create!(date: "2024-06-10")
    end

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2023" => 10, "2024" => 11, "2025" => 10 }, to: { "2023" => 10, "2024" => 10, "2025" => 10 } do
      cycle.deliveries(2024).last.update!(date: "2024-06-11")
    end

    assert_changes -> { cycle.reload.deliveries_counts }, from: { "2023" => 10, "2024" => 10, "2025" => 10 }, to: { "2023" => 10, "2024" => 9, "2025" => 10 } do
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
    org(shop_delivery_open_delay_in_days: 2)
    delivery = deliveries(:monday_1)

    travel_to "2024-03-30 23:59:59" do
      assert delivery.shop_open?
    end
    travel_to "2024-03-31" do
      assert_not delivery.shop_open?
    end
  end

  test "when Organization#shop_delivery_open_last_day_end_time is set" do
    org(shop_delivery_open_last_day_end_time: "12:00")
    delivery = deliveries(:monday_1)

    travel_to "2024-04-01 11:59" do
      assert delivery.shop_open?
    end
    travel_to "2024-04-01 12:00:01" do
      assert_not delivery.shop_open?
    end
  end

  test "when both Organization#shop_delivery_open_delay_in_days and Organization#shop_delivery_open_last_day_end_time are set" do
    org(
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

  test "current_year_ongoing? returns false when no deliveries have passed" do
    travel_to "2024-01-01"

    assert_not Delivery.current_year_ongoing?
  end

  test "current_year_ongoing? returns true when at least one delivery has passed" do
    travel_to "2024-06-01"

    assert Delivery.current_year_ongoing?
  end
end

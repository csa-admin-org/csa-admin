# frozen_string_literal: true

require "test_helper"

class DeliveryCycleTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
  end

  def member_ordered_names
    DeliveryCycle.member_ordered.map(&:name)
  end

  test "member_ordered" do
    create_delivery_cycle(name: "MondaysOdd", results: :odd, wdays: [ 1 ])

    assert_equal %w[All Mondays Thursdays MondaysOdd], member_ordered_names

    org(delivery_cycles_member_order_mode: "deliveries_count_asc")
    assert_equal %w[MondaysOdd Mondays Thursdays All], member_ordered_names

    org(delivery_cycles_member_order_mode: "name_asc")
    assert_equal %w[All Mondays MondaysOdd Thursdays], member_ordered_names

    org(delivery_cycles_member_order_mode: "wdays_asc")
    assert_equal %w[Mondays MondaysOdd All Thursdays], member_ordered_names

    delivery_cycles(:mondays).update!(member_order_priority: 2)
    assert_equal %w[MondaysOdd All Thursdays Mondays], member_ordered_names
  end

  test "only mondays" do
    cycle = delivery_cycles(:mondays)
    assert_equal 10, cycle.current_deliveries_count
    assert_equal 1, cycle.current_deliveries.first.date.wday
  end

  test "only April" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(months: [ 4 ])

    assert_equal 5, cycle.current_deliveries_count
    assert_equal 4, cycle.current_deliveries.first.date.month
  end

  test "only odd weeks" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(week_numbers: :odd)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 15, 17, 19, 21, 23 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "only even weeks" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(week_numbers: :even)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 14, 16, 18, 20, 22 ], cycle.current_deliveries.pluck(:date).map(&:cweek)
  end

  test "all but first results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :all_but_first)

    assert_equal 9, cycle.current_deliveries_count
    assert_equal [ 3, 5, 7, 9, 11, 13, 15, 17, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only odd results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :odd)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 1, 5, 9, 13, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "only even results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :even)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 3, 7, 11, 15, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only first quarter results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :quarter_1)

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 1, 9, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "only second quarter results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :quarter_2)

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 3, 11, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only third quarter results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :quarter_3)

    assert_equal 2, cycle.current_deliveries_count
    assert_equal [ 5, 13 ], cycle.current_deliveries.pluck(:number)
  end

  test "only fourth quarter results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :quarter_4)

    assert_equal 2, cycle.current_deliveries_count
    assert_equal [ 7, 15 ], cycle.current_deliveries.pluck(:number)
  end

  test "only first of each month results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :first_of_each_month)

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 1, 11, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only last of each month results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(results: :last_of_each_month)

    assert_equal 3, cycle.current_deliveries_count
    assert_equal [ 9, 17, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "minimum days gap" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(minimum_gap_in_days: 8)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 1, 5, 9, 13, 17 ], cycle.current_deliveries.pluck(:number)
  end

  test "minimum days gap and all but first results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(minimum_gap_in_days: 8, results: :all_but_first)

    assert_equal 5, cycle.current_deliveries_count
    assert_equal [ 3, 7, 11, 15, 19 ], cycle.current_deliveries.pluck(:number)
  end

  test "only Monday, in April, odd weeks, and even results" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(
      wdays: [ 1 ],
      months: [ 4 ],
      week_numbers: :odd,
      results: :even)

    assert_equal 1, cycle.current_deliveries_count
    delivery = cycle.current_deliveries.first
    assert_equal 1, delivery.date.wday
    assert_equal 17, delivery.date.cweek
    assert_equal 7, delivery.number
  end

  test "reset caches after update" do
    cycle = delivery_cycles(:mondays)

    assert_equal({ "2023" => 10, "2024" => 10, "2025" => 10 }, cycle.deliveries_counts)

    assert_changes -> { cycle.reload.deliveries_counts } do
      cycle.update!(months: [ 4 ])
    end

    assert_equal({ "2023" => 4, "2024" => 5, "2025" => 4 }, cycle.deliveries_counts)
  end

  test "async membership baskets update after config change" do
    cycle = delivery_cycles(:mondays)
    membership = memberships(:john)

    assert_changes -> { membership.baskets.count } do
      cycle.update!(months: [ 4 ])
      perform_enqueued_jobs
    end
  end
end

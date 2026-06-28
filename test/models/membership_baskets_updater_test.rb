# frozen_string_literal: true

require "test_helper"

class MembershipBasketsUpdaterTest < ActiveSupport::TestCase
  def dates(membership)
    membership.deliveries.map(&:date).map(&:to_s)
  end

  test "update membership when cycle updated" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:mondays)
    membership = memberships(:john)

    assert_difference -> { membership.reload.baskets.count }, -7 do
      assert_difference -> { membership.reload.price }, -140 do
        cycle.update!(
          periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
            { from_fy_month: 1, to_fy_month: 12, results: :first_of_each_month }
          ]
        )
        perform_enqueued_jobs
      end
    end
    assert_equal [ "2024-04-01", "2024-05-06", "2024-06-03" ], dates(membership)

    assert_no_difference -> { membership.reload.baskets.count } do
      cycle.update!(wdays: [ 4 ])
      perform_enqueued_jobs
    end
    assert_equal [ "2024-04-04", "2024-05-02", "2024-06-06" ], dates(membership)

    assert_no_difference -> { membership.reload.baskets.count } do
      cycle.update!(wdays: [ 1, 4 ])
      perform_enqueued_jobs
    end
    assert_equal [ "2024-04-01", "2024-05-02", "2024-06-03" ], dates(membership)
  end

  test "only change future baskets" do
    travel_to "2024-05-01"
    cycle = delivery_cycles(:mondays)
    membership = memberships(:john)

    assert_difference -> { membership.reload.baskets.count }, -3 do
      cycle.update!(
        periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
          { from_fy_month: 1, to_fy_month: 12, results: :first_of_each_month }
        ]
      )
      perform_enqueued_jobs
    end

    assert_equal [
     "2024-04-01",
     "2024-04-08",
     "2024-04-15",
     "2024-04-22",
     "2024-04-29",
     "2024-05-06",
     "2024-06-03"
    ], dates(membership)
  end

  test "deletes basket shifts when delivery cycle update removes the target basket" do
    travel_to "2024-01-01"
    cycle = delivery_cycles(:thursdays)
    membership = memberships(:jane)
    source_basket = baskets(:jane_5) # 2024-05-02, kept by first_of_each_month
    target_basket = baskets(:jane_8) # 2024-05-23, removed by first_of_each_month

    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source_basket.delivery,
      target_delivery: target_basket.delivery)

    assert_equal 0, source_basket.reload.quantity
    assert_equal 2, target_basket.reload.quantity

    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 1, to_fy_month: 12, results: :first_of_each_month }
      ]
    )
    perform_enqueued_jobs

    assert_not BasketShift.exists?(shift.id)
    assert_not source_basket.reload.shifted?
    assert_equal 1, source_basket.quantity
  end

  test "leave untouched past baskets of ended membership" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(ended_on: "2024-05-15")

    travel_to "2024-05-01"
    assert_no_difference -> { membership.reload.baskets.count } do
      deliveries(:monday_2).update!(date: "2024-06-13") # Thursday
      perform_enqueued_jobs
    end
  end

  test "update when delivery is created" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_difference -> { membership.reload.baskets.count }, 1 do
      assert_difference -> { membership.reload.price }, 20 do
        Delivery.create!(date: "2024-06-10") # Monday
        perform_enqueued_jobs
      end
    end

    assert_equal [ "2024-06-03", "2024-06-10" ], dates(membership).last(2)
  end

  test "update when delivery date is changing" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_difference -> { membership.reload.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -20 do
        deliveries(:monday_10).update!(date: "2024-06-11") # Tuesday
        perform_enqueued_jobs
      end
    end

    assert_equal [ "2024-05-20", "2024-05-27" ], dates(membership).last(2)
  end

  test "update when delivery date is destroyed" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_difference -> { membership.reload.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -20 do
        deliveries(:monday_9).destroy!
        perform_enqueued_jobs
      end
    end

    assert_equal [ "2024-05-20", "2024-06-03" ], dates(membership).last(2)
  end

  test "updates when destroyed delivery was the only one in membership period" do
    travel_to "2024-01-01"
    membership = memberships(:bob)

    assert_difference -> { membership.reload.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -19 do
        deliveries(:monday_1).destroy!
        perform_enqueued_jobs
      end
    end

    assert_empty dates(membership)
    assert_equal 0, membership.reload.baskets_count
  end

  test "updates when delivery date change removes the only delivery in membership period" do
    travel_to "2024-01-01"
    membership = memberships(:bob)

    assert_difference -> { membership.reload.baskets.count }, -1 do
      assert_difference -> { membership.reload.price }, -19 do
        deliveries(:monday_1).update!(date: "2024-04-02")
        perform_enqueued_jobs
      end
    end

    assert_empty dates(membership)
    assert_equal 0, membership.reload.baskets_count
  end

  test "refreshes activity participations demanded after delivery update" do
    travel_to "2024-01-01"
    org(activity_participations_demanded_logic: "{{ membership.baskets }}")
    delivery = Delivery.create!(date: "2024-04-02")
    delivery_cycle = create_delivery_cycle(wdays: [ 2 ])
    membership = create_membership(
      member: create_member,
      delivery_cycle: delivery_cycle,
      started_on: "2024-01-01",
      ended_on: "2024-12-31")

    assert_equal 1, membership.reload.activity_participations_demanded

    assert_changes -> { membership.reload.activity_participations_demanded }, from: 1, to: 0 do
      delivery.destroy!
      perform_enqueued_jobs
    end
  end
end

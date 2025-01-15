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
        cycle.update!(results: "first_of_each_month")
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
      cycle.update!(results: "first_of_each_month")
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
end

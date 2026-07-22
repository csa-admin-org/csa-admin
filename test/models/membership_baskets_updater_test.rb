# frozen_string_literal: true

require "test_helper"

class MembershipBasketsUpdaterTest < ActiveSupport::TestCase
  def dates(membership)
    membership.deliveries.map(&:date).map(&:to_s)
  end

  def create_delivery_swap!(membership, source:, target:, **attributes)
    basket = membership.baskets.find_by!(delivery: source)
    basket.update!(attributes.merge(delivery: target))
    basket.sync_basket_override!
    BasketOverride.find_by!(membership: membership, delivery: source)
  end

  def assert_delivery_swap_applied(membership, source:, target:)
    assert_not membership.baskets.exists?(delivery: source)
    assert membership.baskets.exists?(delivery: target)
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

  test "preserves delivery swap during delivery resync" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    source = deliveries(:monday_6)
    target = Delivery.create!(date: "2024-05-07") # Tuesday, outside the cycle
    override = create_delivery_swap!(membership, source: source, target: target, quantity: 3)

    deliveries(:monday_10).update!(date: "2024-06-11") # Tuesday
    perform_enqueued_jobs

    assert_delivery_swap_applied(membership, source: source, target: target)
    assert_equal 3, membership.baskets.find_by!(delivery: target).quantity
    assert BasketOverride.exists?(override.id)
  end

  test "restores delivery swap when source is past and target is future" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    source = deliveries(:monday_5)
    target = Delivery.create!(date: "2024-05-07") # Tuesday, outside the cycle
    override = create_delivery_swap!(membership, source: source, target: target, quantity: 3)
    target_basket = membership.baskets.find_by!(delivery: target)
    target_basket.update!(depot: depots(:bakery), depot_price: 4)
    target_basket.sync_basket_override!
    target_override = BasketOverride.find_by!(membership: membership, delivery: target)
    assert_equal depots(:bakery).id, target_override.diff["depot_id"]
    target_basket.destroy!

    travel_to "2024-05-01"
    MembershipBasketsUpdater.new(membership.reload).perform!

    assert_delivery_swap_applied(membership, source: source, target: target)
    target_basket = membership.baskets.find_by!(delivery: target)
    assert_equal 3, target_basket.quantity
    assert_equal depots(:bakery), target_basket.depot
    assert BasketOverride.exists?(override.id)
  end

  test "does not recreate future source when delivery swap target is past" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    source = deliveries(:monday_6)
    target = Delivery.create!(date: "2024-04-30") # Tuesday, outside the cycle
    override = create_delivery_swap!(membership, source: source, target: target)

    travel_to "2024-05-01"
    MembershipBasketsUpdater.new(membership.reload).perform!

    assert_delivery_swap_applied(membership, source: source, target: target)
    assert BasketOverride.exists?(override.id)
  end

  test "preserves delivery swap during alternating delivery cycle resync" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    cycle = membership.delivery_cycle
    period = cycle.periods.first
    cycle.update!(periods_attributes: [ { id: period.id, results: :odd } ])
    perform_enqueued_jobs
    source = deliveries(:monday_5) # Included as the fifth delivery
    target = deliveries(:monday_6) # Excluded as the sixth delivery
    override = create_delivery_swap!(membership, source: source, target: target)

    cycle.update!(last_cweek: 53)
    perform_enqueued_jobs

    assert_delivery_swap_applied(membership, source: source, target: target)
    assert BasketOverride.exists?(override.id)
  end

  test "restores chained delivery swaps" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    source = deliveries(:monday_5)
    intermediate = deliveries(:monday_6)
    target = Delivery.create!(date: "2024-05-07") # Tuesday, outside the cycle
    first_override = create_delivery_swap!(membership, source: intermediate, target: target)
    second_override = create_delivery_swap!(membership, source: source, target: intermediate)
    membership.baskets.find_by!(delivery: intermediate).destroy!

    MembershipBasketsUpdater.new(membership).perform!

    assert_not membership.baskets.exists?(delivery: source)
    assert membership.baskets.exists?(delivery: intermediate)
    assert membership.baskets.exists?(delivery: target)
    assert BasketOverride.exists?(first_override.id)
    assert BasketOverride.exists?(second_override.id)
  end

  test "skips basket resync when delivery swaps share a target" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    target = Delivery.create!(date: "2024-05-07")
    source_ids = [ deliveries(:monday_6).id, deliveries(:monday_7).id ]
    BasketOverride.insert_all!(source_ids.map { |source_id|
      {
        membership_id: membership.id,
        delivery_id: source_id,
        diff: { "override_delivery_id" => target.id },
        created_at: Time.current,
        updated_at: Time.current
      }
    })
    basket_ids = membership.basket_ids.sort

    MembershipBasketsUpdater.new(membership).perform!

    assert_equal basket_ids, membership.reload.basket_ids.sort
    assert_not membership.baskets.exists?(delivery: target)
  end

  test "skips basket resync when delivery swap target is missing" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    BasketOverride.insert_all!([ {
      membership_id: membership.id,
      delivery_id: deliveries(:monday_6).id,
      diff: { "override_delivery_id" => 999_999 },
      created_at: Time.current,
      updated_at: Time.current
    } ])
    basket_ids = membership.basket_ids.sort

    MembershipBasketsUpdater.new(membership).perform!

    assert_equal basket_ids, membership.reload.basket_ids.sort
  end

  test "preserves basket shift during unrelated delivery resync" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source = baskets(:jane_5)
    target = baskets(:jane_6)
    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source.delivery,
      target_delivery: target.delivery)

    deliveries(:monday_10).update!(date: "2024-06-11") # Tuesday
    perform_enqueued_jobs

    assert BasketShift.exists?(shift.id)
    assert_equal 0, source.reload.quantity
    assert_equal 2, target.reload.quantity
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

# frozen_string_literal: true

require "test_helper"

class BasketTest < ActiveSupport::TestCase
  def build_basket(attrs)
    Basket.new({
      membership: memberships(:john)
    }.merge(attrs))
  end

  test "sets prices before validation" do
    delivery_cycles(:mondays).update_column(:price, 3)
    basket = build_basket(
      basket_size: basket_sizes(:medium),
      depot: depots(:home))
    basket.validate

    assert_equal 20, basket.basket_size_price
    assert_equal 9, basket.depot_price
    assert_equal 3, basket.delivery_cycle_price
  end

  test "validates basket_complement_id uniqueness" do
    basket_complement = basket_complements(:eggs)
    basket = build_basket(
      baskets_basket_complements_attributes: {
        "0" => { basket_complement_id: basket_complement.id },
        "1" => { basket_complement_id: basket_complement.id }
      })
    basket.validate
    bbc = basket.baskets_basket_complements.last

    assert_includes bbc.errors[:basket_complement_id], "has already been taken"
  end

  test "validates delivery is in membership date range" do
    basket = build_basket(delivery: deliveries(:monday_future_1))
    basket.validate

    assert_includes basket.errors[:delivery], "is reserved"
  end

  test "updates basket complement_prices when created" do
    travel_to "2024-01-01"
    basket = baskets(:jane_1)
    bread = basket_complements(:bread)
    eggs = basket_complements(:eggs)

    assert_changes -> { basket.reload.complements_price }, from: bread.price, to: bread.price + eggs.price do
      basket.update!(complement_ids: [  bread.id, eggs.id ])
    end
  end

  test "removes basket complement_prices when destroyed" do
    travel_to "2024-01-01"
    basket = baskets(:jane_1)
    bread = basket_complements(:bread)

    assert_changes -> { basket.complements_price }, from: bread.price, to: 0 do
      basket.update!(complement_ids: [])
    end
  end

  test "sets basket_complement on creation when its match membership subscriptions" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    bread = basket_complements(:bread)
    assert_equal [ bread ], membership.subscribed_basket_complements

    delivery = Delivery.create!(
      date: deliveries(:thursday_10).date + 1.week,
      basket_complement_ids: [ bread.id ])
    perform_enqueued_jobs

    basket = delivery.baskets.find_by(membership: membership)
    assert_equal [ bread.id ], basket.complement_ids
    assert_equal bread.price, basket.complements_price
  end

  test "can_member_update?" do
    org(
      membership_depot_update_allowed: false,
      membership_complements_update_allowed: false)
    basket = baskets(:john_1) # monday delivery, 3 visible depots

    travel_to basket.delivery.date
    assert_not basket.can_member_update?, "no updatable section"

    org(membership_depot_update_allowed: true)

    travel_to basket.delivery.date - 5.days
    org(basket_update_limit_in_days: 5)
    assert basket.can_member_update?

    travel_to basket.delivery.date - 4.days
    assert_not basket.can_member_update?, "outside update limit"

    org(basket_update_limit_in_days: 0)

    travel_to basket.delivery.date
    assert basket.can_member_update?
    travel_to basket.delivery.date + 1.day
    assert_not basket.can_member_update?, "delivery date passed"

    travel_to basket.delivery.date
    basket.state = "absent"
    assert_not basket.can_member_update?, "absent basket"
  end

  test "can_member_update_depot?" do
    org(membership_depot_update_allowed: false)
    basket = baskets(:john_1) # mondays cycle, 3 visible depots

    assert_not basket.can_member_update_depot?, "depot update not allowed"

    org(membership_depot_update_allowed: true)
    assert basket.can_member_update_depot?, "3 visible depots"

    # Hide all depots except the current one — use a fresh basket
    # to avoid memoized result on the membership
    Depot.where.not(id: basket.depot_id).update_all(visible: false)
    basket = Basket.find(basket.id)
    assert_not basket.can_member_update_depot?, "single visible depot"
  end

  test "can_member_update_complements?" do
    org(membership_complements_update_allowed: false)
    basket = baskets(:jane_1) # thursday delivery with bread & eggs

    assert_not basket.can_member_update_complements?, "complements update not allowed"

    org(membership_complements_update_allowed: true)
    assert basket.can_member_update_complements?, "delivery has visible complements"

    basket_no_complements = baskets(:john_1) # monday delivery, no complements
    assert_not basket_no_complements.can_member_update_complements?,
      "delivery has no complements"
  end

  test "member_update!" do
    farm = depots(:farm)
    bakery = depots(:bakery)
    basket = baskets(:john_1)

    travel_to "2024-01-01"
    org(membership_depot_update_allowed: false)
    assert_raises(RuntimeError, "update not allowed") do
      basket.member_update!(depot_id: bakery.id)
    end

    org(membership_depot_update_allowed: true)
    assert_changes -> { basket.reload.depot }, from: farm, to: bakery do
      assert_changes -> { basket.reload.depot_price }, from: 0, to: 4 do
        assert_changes -> { basket.reload.membership.price }, from: 200, to: 204 do
          basket.member_update!(depot_id: bakery.id)
        end
      end
    end
  end


  test "calculate_price_extra without basket_price_extra feature" do
    org(features: [])
    basket = build_basket(
      quantity: 2,
      basket_size_price: 19,
      price_extra: 2.42)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when absent (billable)" do
    org(features: [ :basket_price_extra, :absence ], absences_billed: true)
    basket = build_basket(
      state: "absent",
      absence: create_absence(started_on: Date.current, ended_on: 1.week.from_now),
      quantity: 2,
      basket_size_price: 19,
      price_extra: 2.42,
      billable: true)

    assert_equal 2.42, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when non billable basket" do
    org(features: [ :basket_price_extra, :absence ], absences_billed: false)
    basket = build_basket(
      membership: memberships(:john),
      billable: false,
      quantity: 2,
      basket_size_price: 19,
      price_extra: 2.42,
      state: "absent")

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when basket_size_price is zero" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 2,
      basket_size_price: 0,
      price_extra: 2.42)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when quantity is zero" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 0,
      basket_size_price: 19,
      price_extra: 2.42)

    assert_equal 2.42, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when no membership basket_price_extra" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 2,
      basket_size_price: 19,
      price_extra: 0)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra without dynamic pricing" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      membership: memberships(:john),
      quantity: 2,
      basket_size_price: 19,
      price_extra: 2.42)

    assert_equal 2.42, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra with dynamic pricing based on basket_size" do
    org(features: [ :basket_price_extra ])
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% if basket_size_id == #{small_id} %}
        {{ 15 | minus: 10 | divided_by: 3.0 }}
      {% else %}
        2.5
      {% endif %}
    LIQUID
    basket_1 = build_basket(
      basket_size: basket_sizes(:small),
      basket_size_price: 19,
      price_extra: 2,
      quantity: 2)
    basket_2 = build_basket(
      basket_size: basket_sizes(:large),
      basket_size_price: 33,
      price_extra: 2,
      quantity: 2)

    assert_equal 5 / 3.0, basket_1.send(:calculate_price_extra)
    assert_equal 2.5, basket_2.send(:calculate_price_extra)
  end

  test "calculate_price_extra with dynamic pricing based on basket_size and complements prices" do
    org(features: [ :basket_price_extra ])
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% assign price = basket_size_price | plus: complements_price %}
      {{ price | divided_by: 10.0 | times: extra }}
    LIQUID
    basket = baskets(:jane_1)
    basket.price_extra = -20

    assert_equal ((4 + 30) / 10.0 * -20), basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra with dynamic pricing based on deliveries count and extra" do
    org(features: [ :basket_price_extra ])
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {{ extra | divided_by: deliveries_count }}
    LIQUID
    basket = baskets(:jane_1)
    basket.price_extra = 4

    assert_equal 4 / 20.0, basket.send(:calculate_price_extra)
  end

  test "can_force? returns true when provisionally absent and not billable" do
    org(features: [ :absence ])
    basket = baskets(:jane_5) # This is an absent basket

    basket.state = "absent"
    basket.absence_id = nil
    basket.billable = false

    assert basket.can_force?
  end

  test "can_force? returns false when not absent" do
    org(features: [ :absence ])
    basket = baskets(:john_1)

    basket.state = "normal"
    basket.billable = false

    assert_not basket.can_force?
  end

  test "can_force? returns false when billable" do
    org(features: [ :absence ])
    basket = baskets(:jane_5)

    basket.state = "absent"
    basket.absence_id = nil
    basket.billable = true

    assert_not basket.can_force?
  end

  test "can_force? returns false when definitively absent (has absence_id)" do
    org(features: [ :absence ])
    basket = baskets(:jane_5)

    basket.state = "absent"
    basket.absence_id = 1 # Has an absence_id, so not provisional
    basket.billable = false

    assert_not basket.can_force?
  end

  test "can_unforce? returns true when forced" do
    basket = baskets(:john_1)
    basket.state = "forced"

    assert basket.can_unforce?
  end

  test "can_unforce? returns false when not forced" do
    basket = baskets(:john_1)
    basket.state = "normal"

    assert_not basket.can_unforce?
  end

  test "can_member_force? returns true when all conditions are met" do
    org(features: [ :absence ], absence_notice_period_in_days: 7)
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)

    basket = baskets(:jane_10) # Future basket
    basket.state = "absent"
    basket.absence_id = nil

    travel_to basket.delivery.date - 14.days
    assert basket.can_member_force?
  end

  test "can_member_force? returns false when not provisionally absent" do
    org(features: [ :absence ], absence_notice_period_in_days: 7)
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)

    basket = baskets(:jane_10)
    basket.state = "normal"

    travel_to basket.delivery.date - 14.days
    assert_not basket.can_member_force?
  end

  test "can_member_force? returns false when reminder not sent" do
    org(features: [ :absence ], absence_notice_period_in_days: 7)
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, nil)

    basket = baskets(:jane_10)
    basket.state = "absent"
    basket.absence_id = nil

    travel_to basket.delivery.date - 14.days
    assert_not basket.can_member_force?
  end

  test "can_member_force? returns false when outside notice period" do
    org(features: [ :absence ], absence_notice_period_in_days: 7)
    membership = memberships(:jane)
    membership.update_column(:absences_included_reminder_sent_at, Time.current)

    basket = baskets(:jane_10)
    basket.state = "absent"
    basket.absence_id = nil

    # Travel to a date where the delivery is within the notice period
    travel_to basket.delivery.date - 5.days
    assert_not basket.can_member_force?
  end

  test "calculate_basket_size_price" do
    travel_to "2024-01-01"

    basket = build_basket(basket_size: basket_sizes(:medium))
    basket.validate
    assert_equal 20, basket.basket_size_price

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 110)
    basket = build_basket(basket_size: basket_sizes(:medium), delivery: delivery)
    basket.validate
    assert_equal 22, basket.basket_size_price

    delivery.update!(basket_size_price_percentage: 50)
    basket = build_basket(basket_size: basket_sizes(:medium), delivery: delivery)
    basket.validate
    assert_equal 10, basket.basket_size_price

    basket = build_basket(basket_size: basket_sizes(:medium), delivery: delivery, basket_size_price: 42)
    basket.validate
    assert_equal 42, basket.basket_size_price
  end

  test "sets quantity to 0 on creation when basket size default price is 0" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    basket_size.update!(price: 0)

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1), # Jane is on Thursdays, so Monday is free
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 0, basket.quantity
    assert_equal 0, basket.basket_size_price
  end

  test "keeps quantity on creation when basket size is not complements only" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)

    assert_not basket_size.complements_only?

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1), # Jane is on Thursdays, so Monday is free
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 1, basket.quantity
  end

  test "sets quantity to 0 on update when basket size is complements only" do
    travel_to "2024-01-01"
    basket = baskets(:john_1)
    basket_size = basket.basket_size

    assert_equal 1, basket.quantity

    basket_size.update!(price: 0)
    basket.update!(basket_size_price: nil) # Reset to use default

    assert_equal 0, basket.quantity
    assert basket_size.complements_only?
  end

  test "keeps quantity on update when basket size price is explicitly set" do
    travel_to "2024-01-01"
    basket = baskets(:john_1)
    basket_size = basket.basket_size

    assert_equal 1, basket.quantity

    basket_size.update!(price: 0)
    basket.update!(basket_size_price: 5) # explicitly set non-zero price

    assert_equal 1, basket.quantity
  end

  test "sets quantity to 0 on creation when delivery date is before basket size first_cweek" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    # monday_1 is 2024-04-01 which is week 14
    # Set first_cweek to 20 so delivery is before the allowed range
    basket_size.update!(first_cweek: 20)

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1), # 2024-04-01, week 14 - before first_cweek 20
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 0, basket.quantity
  end

  test "sets quantity to 0 on creation when delivery date is after basket size last_cweek" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    # monday_1 is 2024-04-01 which is week 14
    # Set last_cweek to 10 so delivery is after the allowed range
    basket_size.update!(last_cweek: 10)

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1), # 2024-04-01, week 14 - after last_cweek 10
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 0, basket.quantity
  end

  test "keeps quantity on creation when delivery date is within basket size cweek range" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    # monday_1 is 2024-04-01 which is week 14
    basket_size.update!(first_cweek: 10, last_cweek: 20)

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1), # 2024-04-01, week 14 - within range [10, 20]
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 1, basket.quantity
  end

  test "keeps quantity on creation when basket size has no cweek limits" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)

    assert basket_size.always_deliverable?

    basket = Basket.create!(
      membership: memberships(:jane),
      delivery: deliveries(:monday_1),
      basket_size: basket_size,
      depot: depots(:farm),
      quantity: 1)

    assert_equal 1, basket.quantity
  end

  test "does not change quantity on update when outside basket size cweek range" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    basket = baskets(:john_1) # Already created basket
    original_quantity = basket.quantity

    # Update basket size to have a cweek range that excludes this basket's delivery
    basket_size.update!(first_cweek: 50)

    # Update basket - quantity should not change (deliverability is only checked on create)
    basket.update!(depot: depots(:bakery))

    assert_equal original_quantity, basket.quantity
  end
end

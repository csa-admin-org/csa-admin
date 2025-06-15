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

    assert_equal 20, basket.basket_price
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
    org(membership_depot_update_allowed: false)

    delivery = deliveries(:monday_1) # 2024-01-01
    basket = Basket.new(delivery: delivery)

    travel_to delivery.date
    assert_not basket.can_member_update?

    org(membership_depot_update_allowed: true)
    org(basket_update_limit_in_days: 5)

    travel_to delivery.date - 5.days
    assert basket.can_member_update?

    travel_to delivery.date - 4.days
    assert_not basket.can_member_update?

    org(basket_update_limit_in_days: 0)

    travel_to delivery.date
    assert basket.can_member_update?
    travel_to delivery.date + 1.day
    assert_not basket.can_member_update?

    travel_to delivery.date
    basket.state = "absent"
    assert_not basket.can_member_update?
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

  test "decline shift" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?

    assert_changes -> { basket.reload.shift_declined_at }, from: nil do
      basket.update!(shift_target_basket_id: "declined")
    end
    assert basket.shift_declined?
    assert basket.can_be_shifted?
    assert_equal "declined", basket.shift_target_basket_id
  end

  test "cancel declined shift" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?
    basket.touch(:shift_declined_at)

    assert_changes -> { basket.reload.shift_declined_at }, to: nil do
      basket.update!(shift_target_basket_id: "")
    end
    assert basket.can_be_shifted?
    assert_not basket.shift_declined?
    assert_nil basket.shift_declined_at
    assert_not basket.shifted?
  end

  test "shift content to another basket" do
    basket = baskets(:jane_5)
    assert basket.can_be_shifted?
    basket.touch(:shift_declined_at)

    assert_changes -> { basket.reload.shift_as_source }, from: nil do
      basket.update!(shift_target_basket_id: baskets(:jane_8).id)
    end
    assert_not basket.can_be_shifted?
    assert_nil basket.shift_declined_at
    assert basket.shifted?
    assert_equal baskets(:jane_8).id, basket.shift_target_basket_id
  end

  test "#member_shiftable_basket_targets" do
    org(basket_shift_deadline_in_weeks: nil)
    basket = baskets(:jane_5)
    travel_to basket.delivery.date

    assert basket.can_be_shifted?
    assert_not basket.membership.basket_shift_allowed?
    assert_empty basket.member_shiftable_basket_targets

    org(basket_shifts_annually: 1)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7),
      baskets(:jane_8),
      baskets(:jane_9),
      baskets(:jane_10)
    ], basket.member_shiftable_basket_targets

    org(basket_shift_deadline_in_weeks: 2)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets

    travel_to basket.delivery.date - 2.weeks
    assert_equal [
      baskets(:jane_4),
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets
  end

  test "calculate_price_extra without basket_price_extra feature" do
    org(features: [])
    basket = build_basket(
      quantity: 2,
      basket_price: 19,
      price_extra: 2.42)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when absent (billable)" do
    org(features: [ :basket_price_extra, :absence ], absences_billed: true)
    basket = build_basket(
      state: "absent",
      absence: create_absence(started_on: Date.today, ended_on: 1.week.from_now),
      quantity: 2,
      basket_price: 19,
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
      basket_price: 19,
      price_extra: 2.42,
      state: "absent")

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when basket_price is zero" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 2,
      basket_price: 0,
      price_extra: 2.42)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when quantity is zero" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 0,
      basket_price: 19,
      price_extra: 2.42)

    assert_equal 2.42, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra when no membership basket_price_extra" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      quantity: 2,
      basket_price: 19,
      price_extra: 0)

    assert_equal 0, basket.send(:calculate_price_extra)
  end

  test "calculate_price_extra without dynamic pricing" do
    org(features: [ :basket_price_extra ])
    basket = build_basket(
      membership: memberships(:john),
      quantity: 2,
      basket_price: 19,
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
      basket_price: 19,
      price_extra: 2,
      quantity: 2)
    basket_2 = build_basket(
      basket_size: basket_sizes(:large),
      basket_price: 33,
      price_extra: 2,
      quantity: 2)

    assert_equal 5 / 3.0, basket_1.send(:calculate_price_extra)
    assert_equal 2.5, basket_2.send(:calculate_price_extra)
  end

  test "calculate_price_extra with dynamic pricing based on basket_size and complements prices" do
    org(features: [ :basket_price_extra ])
    org(basket_price_extra_dynamic_pricing: <<-LIQUID)
      {% assign price = basket_price | plus: complements_price %}
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
end

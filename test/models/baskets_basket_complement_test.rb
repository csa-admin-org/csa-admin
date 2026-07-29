# frozen_string_literal: true

require "test_helper"

class BasketsBasketComplementTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
  end

  test "handle_deliveries_addition! adds complement from membership subscription" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    membership.memberships_basket_complements.find_by!(basket_complement: eggs)
      .update!(quantity: 2, price: 7.5)
    delivery = deliveries(:monday_1)
    schedule_complement_on_delivery!(eggs, delivery)
    basket = membership.baskets.find_by!(delivery: delivery)

    basket_ids = nil
    assert_difference -> { BasketsBasketComplement.where(basket: basket, basket_complement: eggs).count }, 1 do
      basket_ids = BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)
    end

    assert_equal [ basket.id ], basket_ids
    bbc = basket.baskets_basket_complements.find_by!(basket_complement: eggs)
    assert_equal 2, bbc.quantity
    assert_equal 7.5, bbc.price
    assert_equal eggs.id, basket.reload.complement_ids.sole
    assert_equal 15, basket.complements_price
  end

  test "handle_deliveries_addition! is idempotent when complement already present" do
    eggs = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ eggs.id ])
    delivery = deliveries(:monday_1)
    schedule_complement_on_delivery!(eggs, delivery)

    BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)

    assert_no_difference -> { BasketsBasketComplement.count } do
      BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)
    end
  end

  test "handle_deliveries_addition! skips baskets whose membership is not subscribed" do
    eggs = basket_complements(:eggs)
    delivery = deliveries(:monday_1)
    schedule_complement_on_delivery!(eggs, delivery)

    assert_no_difference -> { BasketsBasketComplement.where(basket_complement: eggs).count } do
      BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)
    end
    assert_empty memberships(:john).baskets.find_by!(delivery: delivery).complement_ids
  end

  test "handle_deliveries_addition! is a no-op when delivery is no longer scheduled" do
    eggs = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ eggs.id ])
    delivery = deliveries(:monday_1)

    assert_no_difference -> { BasketsBasketComplement.count } do
      BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)
    end
  end

  test "handle_deliveries_addition! only affects the given delivery" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    delivery = deliveries(:monday_1)
    schedule_complement_on_delivery!(eggs, delivery)

    BasketsBasketComplement.handle_deliveries_addition!(delivery, eggs)

    assert_equal [ eggs.id ], membership.baskets.find_by!(delivery: delivery).complement_ids
    assert_empty membership.baskets.find_by!(delivery: deliveries(:monday_2)).complement_ids
  end

  test "handle_deliveries_removal! removes only the given complement on that delivery" do
    bread = basket_complements(:bread)
    eggs = basket_complements(:eggs)
    membership = memberships(:jane)
    delivery = deliveries(:thursday_1)
    basket = membership.baskets.find_by!(delivery: delivery)
    schedule_complement_on_delivery!(eggs, delivery)
    basket.baskets_basket_complements.create!(
      basket_complement: eggs,
      quantity: 1,
      price: eggs.price)

    assert_equal [ bread.id, eggs.id ].sort, basket.reload.complement_ids.sort

    BasketsBasketComplement.handle_deliveries_removal!(delivery, bread)

    assert_equal [ eggs.id ], basket.reload.complement_ids
    assert_equal [ bread.id ], membership.baskets.find_by!(delivery: deliveries(:thursday_2)).complement_ids
  end

  test "handle_deliveries_removal! is a no-op when nothing matches" do
    eggs = basket_complements(:eggs)

    assert_no_difference -> { BasketsBasketComplement.count } do
      BasketsBasketComplement.handle_deliveries_removal!(deliveries(:monday_1), eggs)
    end
  end

  private

  def schedule_complement_on_delivery!(complement, delivery)
    return if delivery.basket_complement_ids.include?(complement.id)

    ActiveRecord::Base.connection.insert(<<~SQL.squish)
      INSERT INTO basket_complements_deliveries (basket_complement_id, delivery_id)
      VALUES (#{complement.id}, #{delivery.id})
    SQL
    delivery.association(:basket_complements).reset
    complement.instance_variable_set(:@current_and_future_delivery_ids, nil)
    complement.instance_variable_set(:@delivery_ids, nil)
  end
end

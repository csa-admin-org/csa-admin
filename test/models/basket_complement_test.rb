# frozen_string_literal: true

require "test_helper"

class BasketComplementTest < ActiveSupport::TestCase
  def member_ordered_names
    BasketComplement.member_ordered.map(&:name)
  end

  test "member_ordered" do
    travel_to "2024-01-01"
    basket_complements(:eggs)
      .update!(price: 5, delivery_ids: [ deliveries(:monday_1).id ])
    basket_complements(:cheese)
      .update!(price: 6, delivery_ids: deliveries(:monday_1, :monday_2, :monday_3).pluck(:id))
    basket_complements(:bread)
      .update!(price: 7, delivery_ids: deliveries(:monday_1, :monday_2).pluck(:id))

    # deliveries_count_desc is the default
    assert_equal %w[ Cheese Bread Eggs ], member_ordered_names

    org(basket_complements_member_order_mode: "price_asc")
    assert_equal %w[ Eggs Cheese Bread ], member_ordered_names

    org(basket_complements_member_order_mode: "price_desc")
    assert_equal %w[ Bread Cheese Eggs ], member_ordered_names

    org(basket_complements_member_order_mode: "deliveries_count_asc")
    assert_equal %w[ Eggs Bread Cheese ], member_ordered_names

    org(basket_complements_member_order_mode: "name_asc")
    assert_equal %w[ Bread Cheese Eggs ], member_ordered_names

    basket_complements(:eggs).update!(member_order_priority: 0)
    assert_equal %w[ Eggs Bread Cheese ], member_ordered_names
  end

  test "deliveries_count counts future deliveries when exists" do
    travel_to "2024-01-01"
    c = basket_complements(:cheese)

    deliveries(:monday_1, :monday_2).each do |delivery|
      delivery.update!(basket_complement_ids: [ c.id ])
    end

    assert_changes -> { BasketComplement.find(c.id).deliveries_count }, from: 2, to: 1 do
      deliveries(:monday_future_1).update!(basket_complement_ids: [ c.id ])
    end
  end

  test "adds/removes basket_complement on subscribed baskets" do
    travel_to "2024-01-01"
    c1 = basket_complements(:eggs)
    c2 = basket_complements(:cheese)

    memberships(:john).update!(subscribed_basket_complement_ids: [ c1.id, c2.id ])

    assert_changes -> { baskets(:john_1).reload.complement_ids }, from: [], to: [ c1.id ] do
      c1.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end
    assert_equal 6, baskets(:john_1).complements_price

    assert_changes -> { baskets(:john_1).reload.complement_ids }, from: [ c1.id ], to: [ c1.id, c2.id ] do
      c2.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end
    assert_equal 6 + 5, baskets(:john_1).complements_price

    assert_changes -> { baskets(:john_1).reload.complement_ids }, from: [ c1.id, c2.id ], to: [ c2.id ] do
      c1.update!(current_delivery_ids: [])
    end
    assert_equal 5, baskets(:john_1).complements_price
  end

  test "does not modify basket_complement on subscribed baskets for past deliveries" do
    travel_to "2024-01-01"
    c = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ c.id ])
    c.update!(current_delivery_ids: [ deliveries(:monday_1).id ])

    travel_to "2025-01-01"
    c.reload
    assert_no_changes -> { baskets(:john_1).reload.complement_ids }, from: [ c.id ] do
      c.update!(current_delivery_ids: [])
    end
  end
end

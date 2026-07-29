# frozen_string_literal: true

require "test_helper"

class BasketsBasketComplementsUpdaterJobTest < ActiveJob::TestCase
  setup do
    travel_to "2024-01-01"
  end

  test "enqueues after the transaction commits" do
    delivery = deliveries(:monday_1)
    complement = basket_complements(:eggs)

    assert_enqueued_jobs 1, only: BasketsBasketComplementsUpdaterJob do
      Delivery.transaction do
        delivery.basket_complements << complement

        assert_no_enqueued_jobs only: BasketsBasketComplementsUpdaterJob
      end
    end
  end

  test "adds complement to subscribed baskets across deliveries" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    membership.memberships_basket_complements.find_by!(basket_complement: eggs)
      .update!(quantity: 2, price: 7.5)

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id, deliveries(:monday_2).id ])
    end

    [ deliveries(:monday_1), deliveries(:monday_2) ].each do |delivery|
      bbc = membership.baskets.find_by!(delivery: delivery)
        .baskets_basket_complements.find_by!(basket_complement: eggs)
      assert_equal 2, bbc.quantity
      assert_equal 7.5, bbc.price
    end
    assert_empty membership.baskets.find_by!(delivery: deliveries(:monday_3)).complement_ids
  end

  test "does not add complement to unsubscribed memberships on the same delivery" do
    eggs = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ eggs.id ])

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    john_basket = memberships(:john).baskets.find_by!(delivery: deliveries(:monday_1))
    bob_basket = memberships(:bob).baskets.find_by!(delivery: deliveries(:monday_1))
    assert_equal [ eggs.id ], john_basket.complement_ids
    assert_empty bob_basket.complement_ids
  end

  test "removes complement from subscribed baskets across deliveries" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id, deliveries(:monday_2).id ])
    end
    assert_equal [ eggs.id ], basket_for(membership, :monday_1).complement_ids
    assert_equal [ eggs.id ], basket_for(membership, :monday_2).complement_ids

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    assert_equal [ eggs.id ], basket_for(membership, :monday_1).reload.complement_ids
    assert_empty basket_for(membership, :monday_2).reload.complement_ids
  end

  test "updates membership price after addition and removal" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    membership.send(:update_price_and_invoices_amount!)
    base_price = membership.reload.price

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    assert_equal base_price + eggs.price, membership.reload.price

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [])
    end

    assert_equal base_price, membership.reload.price
    assert_empty basket_for(membership, :monday_1).reload.complement_ids
  end

  test "updates baskets_count when complement fills an empty basket" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    basket = basket_for(membership, :monday_1)
    basket.update!(quantity: 0)
    membership.update_baskets_counts!
    assert_equal 9, membership.reload.baskets_count

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    assert_equal 10, membership.reload.baskets_count
    assert_predicate basket.reload, :deliverable?
  end

  test "updates calculated_price_extra when dynamic pricing uses complements_price" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    basket = basket_for(membership, :monday_1)
    basket.update!(price_extra: 1)

    org(basket_price_extra_dynamic_pricing: <<~LIQUID)
      {% assign price = basket_size_price | plus: complements_price %}
      {{ price | times: extra }}
    LIQUID

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    # (20 + 6) * 1
    assert_equal 26, basket.reload.calculated_price_extra

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [])
    end

    # (20 + 0) * 1
    assert_equal 20, basket.reload.calculated_price_extra
  end

  test "touches basket updated_at so calendar freshness moves forward" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])
    basket = basket_for(membership, :monday_1)
    basket.update_columns(updated_at: 2.days.ago)
    before = basket.reload.updated_at

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
    end

    assert_operator basket.reload.updated_at, :>, before
  end

  test "addition is idempotent when job runs twice" do
    eggs = basket_complements(:eggs)
    membership = memberships(:john)
    membership.update!(subscribed_basket_complement_ids: [ eggs.id ])

    2.times do
      perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
        eggs.update!(current_delivery_ids: [ deliveries(:monday_1).id ])
      end
    end

    assert_equal 1, BasketsBasketComplement.where(
      basket: basket_for(membership, :monday_1),
      basket_complement: eggs).count
  end

  test "does not rewrite unrelated trial basket states during bulk add" do
    eggs = basket_complements(:eggs)
    membership = memberships(:jane)
    membership.update!(subscribed_basket_complement_ids: [ bread_id, eggs.id ])
    trial_before = membership.baskets.trial.order(:id).pluck(:id, :state)
    delivery_ids = membership.deliveries.limit(2).pluck(:id)

    perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
      eggs.update!(current_delivery_ids: delivery_ids)
    end

    trial_after = membership.baskets.order(:id).where(id: trial_before.map(&:first)).pluck(:id, :state)
    assert_equal trial_before, trial_after
  end

  test "bulk addition stays within a membership-size-independent query budget" do
    eggs = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ eggs.id ])
    delivery_ids = deliveries(:monday_1, :monday_2, :monday_3).map(&:id)

    sql_count = count_sql_queries do
      perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
        eggs.update!(current_delivery_ids: delivery_ids)
      end
    end

    assert_operator sql_count, :<, 100,
      "expected bulk complement add to stay lean (got #{sql_count} SQL statements)"
  end

  test "bulk addition does not touch memberships via cascade" do
    eggs = basket_complements(:eggs)
    memberships(:john).update!(subscribed_basket_complement_ids: [ eggs.id ])
    delivery_ids = deliveries(:monday_1, :monday_2, :monday_3).map(&:id)

    membership_touches = 0
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql].to_s
      membership_touches += 1 if sql.include?(%(UPDATE "memberships" SET "updated_at"))
    }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      perform_enqueued_jobs only: BasketsBasketComplementsUpdaterJob do
        eggs.update!(current_delivery_ids: delivery_ids)
      end
    end

    assert_equal 0, membership_touches,
      "bulk complement sync must not touch memberships (got #{membership_touches})"
  end

  private

  def basket_for(membership, delivery_name)
    membership.baskets.find_by!(delivery: deliveries(delivery_name))
  end

  def count_sql_queries
    count = 0
    callback = ->(*) { count += 1 }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    count
  end
end

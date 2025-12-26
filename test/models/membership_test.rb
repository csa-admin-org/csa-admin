# frozen_string_literal: true

require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "validations allow only one current membership per member" do
    travel_to "2024-01-01"
    membership = build_membership(member: members(:john))

    assert_not membership.valid?
    assert_includes membership.errors[:member], "has already been taken"
  end

  test "validations allow valid attributes" do
    travel_to "2024-01-01"
    membership = build_membership

    assert membership.valid?
  end

  test "validations allow started_on to be only smaller than ended_on" do
    membership = build_membership(
      started_on: Date.new(2015, 2),
      ended_on: Date.new(2015, 1))

    assert_not membership.valid?
    assert_includes membership.errors[:started_on], "must be before the end"
    assert_includes membership.errors[:ended_on], "must be after the start"
  end

  test "validations allow started_on to be only on the same year than ended_on" do
    membership = build_membership(
      started_on: Date.new(2024, 1),
      ended_on: Date.new(2015, 12))

    assert_not membership.valid?
    assert_includes membership.errors[:started_on], "must be in the same fiscal year"
    assert_includes membership.errors[:ended_on], "must be in the same fiscal year"
  end

  test "validates basket_complement_id uniqueness" do
    membership = build_membership(
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id },
        "1" => { basket_complement_id: bread_id }
      })

    assert_not membership.valid?
    mbc = membership.memberships_basket_complements.last
    assert_includes mbc.errors[:basket_complement_id], "has already been taken"
  end

  test "creates baskets on creation" do
    travel_to "2024-01-01"
    membership = build_membership(
      basket_size: basket_sizes(:small),
      depot: depots(:farm))

    assert_difference -> { membership.baskets.count }, 10 do
      membership.save!
    end

    assert_equal [ small_id ], membership.baskets.map(&:basket_size_id).uniq
    assert_equal [ farm_id ], membership.baskets.map(&:depot_id).uniq
  end

  test "creates baskets with complements on creation" do
    travel_to "2024-01-01"
    membership = build_membership(
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, price: "", quantity: 1 },
        "1" => { basket_complement_id: eggs_id, price: "4.5", quantity: 2 }
      })

    assert_difference -> { membership.baskets.count }, 10 do
      membership.save!
    end

    basket = membership.baskets.first
    # Bread comes before Eggs alphabetically
    assert_equal [ bread_id, eggs_id ], basket.complement_ids
    assert_equal 4 + 2 * 4.5, basket.complements_price
  end

  test "deletes and creates baskets when started_on and ended_on changes" do
    travel_to "2024-05-01"
    membership = memberships(:jane)
    first_basket = membership.baskets.first
    last_basket = membership.baskets.last

    assert_difference -> { membership.reload.baskets_count }, -2 do
      assert_difference -> { membership.reload.price }, -76 do
        membership.update!(
          started_on: first_basket.delivery.date + 1.day,
          ended_on: last_basket.delivery.date - 1.day)
      end
    end

    assert_raises(ActiveRecord::RecordNotFound) { first_basket.reload }
    assert_raises(ActiveRecord::RecordNotFound) { last_basket.reload }

    assert_difference -> { membership.reload.baskets_count }, 2 do
      assert_difference -> { membership.reload.price }, 76 do
        membership.update!(
          started_on: membership.started_on - 1.day,
          ended_on: membership.ended_on + 1.day)
      end
    end
  end

  test "re-creates future baskets by default" do
    travel_to "2024-06-01"
    membership = memberships(:john)

    assert_equal Date.current, membership.new_config_from
    assert_no_difference -> { membership.reload.baskets_count } do
      membership.update!(basket_size_id: small_id, depot_id: bakery_id)
    end

    assert_equal [
      [ medium_id, farm_id ],
      [ medium_id, farm_id ],
      [ small_id, bakery_id ]
    ], membership.baskets.last(3).pluck(:basket_size_id, :depot_id)
  end

  test "re-creates baskets from a given date" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_no_difference -> { membership.reload.baskets_count } do
      membership.update!(
        new_config_from: "2024-06-01",
        basket_size_id: small_id,
        depot_id: bakery_id)
    end

    assert_equal [
      [ medium_id, farm_id ],
      [ medium_id, farm_id ],
      [ small_id, bakery_id ]
    ], membership.baskets.last(3).pluck(:basket_size_id, :depot_id)
  end

  test "re-creates baskets when only new_config_from change" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_no_difference -> { membership.reload.baskets_count } do
      assert_difference -> { membership.reload.baskets.last.id } do
        membership.update!(new_config_from: "2024-06-01")
      end
    end
  end

  test "adds basket_complement to coming baskets when membership is added" do
    travel_to "2024-01-01"
    deliveries(:monday_8).update!(basket_complement_ids: [ bread_id ])
    deliveries(:monday_9).update!(basket_complement_ids: [ eggs_id, bread_id ])
    deliveries(:monday_10).update!(basket_complement_ids: [ eggs_id, cheese_id ])

    membership = create_membership(
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, price: "", quantity: 2 },
        "1" => { basket_complement_id: eggs_id, price: "6.4", quantity: 1 }
      })

    # Bread comes before Eggs alphabetically
    assert_equal [
      [],
      [ bread_id ],
      [ bread_id, eggs_id ],
      [ eggs_id ]
    ], membership.baskets.last(4).map(&:complement_ids)

    assert_equal [
      0,
      4 * 2,
      6.4 + 4 * 2,
      6.4
    ], membership.baskets.last(4).map(&:complements_price)
  end

  test "removes basket_complement to coming baskets when membership is removed" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_equal [ [ bread_id ] ], membership.baskets.map(&:complement_ids).uniq

    complements = membership.memberships_basket_complements
    membership.update!(memberships_basket_complements_attributes: {
      "0" => { basket_complement_id: bread_id, id: complements.first.id, _destroy: complements.first.id },
      "1" => { basket_complement_id: eggs_id }
    })

    membership.reload
    assert_equal [ [ eggs_id ] ], membership.baskets.map(&:complement_ids).uniq
  end

  test "clears member waiting info after creation" do
    travel_to "2024-01-01"
    member = members(:aria)
    member.update!(waiting_basket_complement_ids: [ bread_id ])

    create_membership(member: member)

    assert_nil member.reload.waiting_started_at
    assert_nil member.waiting_basket_size_id
    assert_nil member.waiting_depot_id
    assert_nil member.waiting_delivery_cycle_id
    assert_empty member.waiting_basket_complement_ids
  end

  test "updates futures basket when configuration change" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_changes -> { membership.baskets.pluck(:basket_size_price) }, from:  [ 20 ] * 10, to: [ 21 ] * 10 do
      membership.update!(basket_size_price: 21)
    end
  end

  test "updates future baskets price_extra when config change" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(basket_price_extra: 2)
    membership.update!(
      new_config_from: "2024-05-01",
      basket_price_extra: 3)

    assert_equal [ 2 ] * 5 + [ 3 ] * 5, membership.baskets.pluck(:price_extra)
  end

  test "updates baskets counts after commit" do
    travel_to "2024-04-15"
    member = members(:mary)
    member.update!(trial_baskets_count: 5)
    membership = create_membership(member: member)

    assert_equal 10, membership.baskets_count
    assert_equal 2, membership.past_baskets_count
    assert_equal 3, membership.remaining_trial_baskets_count
    assert membership.trial?
  end

  test "baskets counts does not count empty baskets" do
    travel_to "2024-05-15"
    membership = memberships(:jane)
    membership.touch

    assert_equal 10, membership.baskets_count
    assert_equal 6, membership.past_baskets_count

    membership.baskets.first.update!(quantity: 0)
    membership.baskets.first.baskets_basket_complements.first.update!(quantity: 0)

    assert_equal 9, membership.baskets_count
    assert_equal 5, membership.past_baskets_count
  end

  test "baskets counts does not count non-billable baskets" do
    travel_to "2024-05-15"
    membership = memberships(:jane)
    membership.touch

    assert_equal 10, membership.baskets_count
    assert_equal 6, membership.past_baskets_count

    membership.update!(absences_included_annually: 3)

    assert_equal 7, membership.baskets_count
    assert_equal 5, membership.past_baskets_count
  end

  test "changing basket size deletes bidding round pledge" do
    travel_to("2024-01-01")

    pledge = BiddingRound::Pledge.create!(
      bidding_round: bidding_rounds(:open_2024),
      membership: memberships(:jane),
      basket_size_price: 31)

    memberships(:jane).update!(basket_size: basket_sizes(:small))

    assert_raise ActiveRecord::RecordNotFound do
      pledge.reload
    end
  end

  test "can_member_update?" do
    org(membership_depot_update_allowed: false)
    membership = memberships(:john)

    travel_to "2024-01-01"
    assert_not membership.can_member_update?

    org(membership_depot_update_allowed: true, basket_update_limit_in_days: 5)

    travel_to membership.baskets.last.delivery.date - 5.days
    assert membership.can_member_update?

    travel_to membership.baskets.last.delivery.date - 4.days
    assert_not membership.can_member_update?

    org(basket_update_limit_in_days: 0)

    travel_to membership.baskets.last.delivery.date
    assert membership.can_member_update?

    travel_to membership.baskets.last.delivery.date + 1.day
    assert_not membership.can_member_update?
  end

  test "member_update!" do
    travel_to "2024-01-01"
    org(membership_depot_update_allowed: false)
    membership = memberships(:john)

    assert_raises(RuntimeError, "update not allowed") do
      membership.member_update!(depot_id: home_id)
    end

    travel_to membership.baskets.last.delivery.date - 8.days
    org(membership_depot_update_allowed: true, basket_update_limit_in_days: 1)
    assert_changes -> { membership.reload.depot_id }, from: farm_id, to: home_id do
      assert_changes -> { membership.reload.depot_price }, from: 0, to: 9 do
        assert_changes -> { membership.baskets.last.depot_id }, from: farm_id, to: home_id do
          assert_changes -> { membership.baskets.last(2).first.depot_id }, from: farm_id, to: home_id do
            assert_no_changes -> { membership.baskets.last(3).first.depot_id }, from: farm_id do
              assert_difference -> { membership.price }, 18 do
                membership.member_update!(depot_id: home_id)
              end
            end
          end
        end
      end
    end
  end

  test "activates pending member on creation" do
    member = members(:aria)
    assert_changes -> { member.reload.state }, from: "waiting", to: "active" do
      create_membership(member: member)
    end
  end

  test "creates baskets with default basket_size_price and applies delivery percentage" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership.update!(new_config_from: Date.current, basket_size_price: nil)

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 10, basket.basket_size_price # 20 * 0.5
  end

  test "can be destroyed" do
    membership = memberships(:jane)

    assert_difference -> { Membership.count }, -1 do
      membership.destroy
    end
  end

  test "creates baskets with quantity 0 when basket size is complements only" do
    travel_to "2024-01-01"
    basket_size = basket_sizes(:small)
    basket_size.update!(price: 0)

    membership = build_membership(basket_size: basket_size)

    assert_difference -> { membership.baskets.count }, 10 do
      membership.save!
    end

    membership.baskets.each do |basket|
      assert_equal 0, basket.quantity, "Basket should have quantity 0 for complements only basket size"
      assert_equal 0, basket.basket_size_price
    end
  end
end

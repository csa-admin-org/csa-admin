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
    travel_to "2024-01-01"
    member = members(:aria)
    assert_changes -> { member.reload.state }, from: "waiting", to: "active" do
      create_membership(member: member)
    end
  end

  test "creates baskets with default basket_size_price and applies delivery percentage" do
    travel_to "2024-01-01"

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership = create_membership(basket_size: basket_sizes(:medium))

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 10, basket.basket_size_price # basket_size.price (20) * 0.5

    # Other baskets without percentage keep the default price
    other_basket = membership.baskets.where.not(delivery: delivery).first
    assert_equal 20, other_basket.basket_size_price
  end

  test "applies delivery percentage to explicit basket_size_price when apply_basket_size_price_percentage is true" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership.update!(
      new_config_from: Date.current,
      basket_size_price: 25,
      apply_basket_size_price_percentage: true)

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 12.5, basket.basket_size_price # 25 * 0.5

    # Other baskets without percentage keep the explicit price
    other_basket = membership.baskets.where.not(delivery: delivery).first
    assert_equal 25, other_basket.basket_size_price
  end

  test "does not apply delivery percentage to explicit basket_size_price when apply_basket_size_price_percentage is false" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership.update!(
      new_config_from: Date.current,
      basket_size_price: 25,
      apply_basket_size_price_percentage: false)

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 25, basket.basket_size_price # No percentage applied
  end

  test "does not apply delivery percentage to default price when apply_basket_size_price_percentage is false" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership.update!(
      new_config_from: Date.current,
      basket_size_price: nil,
      apply_basket_size_price_percentage: false)

    # basket_size_price is blank, but apply is false, so basket gets the
    # membership's resolved basket_size_price (basket_size.price = 20) as-is
    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 20, basket.basket_size_price
  end

  test "toggling apply_basket_size_price_percentage triggers basket regeneration" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    delivery = deliveries(:monday_1)
    delivery.update!(basket_size_price_percentage: 50)

    membership.update!(
      new_config_from: Date.current,
      basket_size_price: 25,
      apply_basket_size_price_percentage: true)

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 12.5, basket.basket_size_price

    membership.update!(
      new_config_from: Date.current,
      apply_basket_size_price_percentage: false)

    basket = membership.baskets.find_by(delivery: delivery)
    assert_equal 25, basket.basket_size_price
  end

  test "fiscal_year_has_basket_size_price_percentage? returns true when deliveries have percentage" do
    travel_to "2024-01-01"
    membership = memberships(:john)

    assert_not membership.fiscal_year_has_basket_size_price_percentage?

    deliveries(:monday_1).update!(basket_size_price_percentage: 50)

    assert membership.fiscal_year_has_basket_size_price_percentage?
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

  # == Alternate depot ==

  test "alternate depot: creates baskets with correct depot per delivery" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      depot: depots(:farm),
      alternate_depot: depots(:bakery),
      alternate_depot_price: 4,
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    monday_baskets = membership.baskets.joins(:delivery).where(deliveries: { date: Delivery.where("time_get_weekday(time_parse(date)) = 1").select(:date) })
    thursday_baskets = membership.baskets.joins(:delivery).where(deliveries: { date: Delivery.where("time_get_weekday(time_parse(date)) = 4").select(:date) })

    assert_equal [ farm_id ], monday_baskets.pluck(:depot_id).uniq
    assert_equal [ 0 ], monday_baskets.pluck(:depot_price).uniq.map(&:to_i)
    assert_equal [ bakery_id ], thursday_baskets.pluck(:depot_id).uniq
    assert_equal [ 4 ], thursday_baskets.pluck(:depot_price).uniq.map(&:to_i)
    assert_equal 20, membership.baskets.count
  end

  test "alternate depot: changing config triggers basket regeneration" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      depot: depots(:farm))

    assert_equal [ farm_id ], membership.baskets.pluck(:depot_id).uniq

    membership.update!(
      new_config_from: Date.current,
      alternate_depot_id: bakery_id,
      alternate_depot_price: 4,
      alternate_delivery_cycle_id: thursdays_id)

    thursday_baskets = membership.baskets.where(depot_id: bakery_id)
    assert thursday_baskets.count.positive?
    assert_equal 10, thursday_baskets.count
  end

  test "alternate depot: validation requires both depot and cycle together" do
    travel_to "2024-01-01"

    membership = build_membership(
      alternate_depot: depots(:bakery),
      alternate_delivery_cycle: nil)
    assert_not membership.valid?
    assert membership.errors[:alternate_depot].any?

    membership = build_membership(
      alternate_depot: nil,
      alternate_delivery_cycle: delivery_cycles(:thursdays))
    assert_not membership.valid?
    assert membership.errors[:alternate_delivery_cycle].any?
  end

  test "alternate depot: validation rejects same cycle as main" do
    travel_to "2024-01-01"
    membership = build_membership(
      delivery_cycle: delivery_cycles(:mondays),
      alternate_depot: depots(:bakery),
      alternate_delivery_cycle: delivery_cycles(:mondays))

    assert_not membership.valid?
    assert membership.errors[:alternate_delivery_cycle].any?
  end

  test "alternate depot: validation rejects cycle with no shared deliveries" do
    travel_to "2024-01-01"
    membership = build_membership(
      delivery_cycle: delivery_cycles(:mondays),
      depot: depots(:farm),
      alternate_depot: depots(:bakery),
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    assert_not membership.valid?
    assert membership.errors[:alternate_delivery_cycle].any?
  end

  test "alternate depot: defaults price from alternate depot" do
    travel_to "2024-01-01"
    membership = build_membership(
      delivery_cycle: delivery_cycles(:all),
      alternate_depot: depots(:home),
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    membership.validate
    assert_equal 9, membership.alternate_depot_price
  end

  test "alternate depot: clears price when depot is cleared" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      depot: depots(:farm),
      alternate_depot: depots(:bakery),
      alternate_depot_price: 4,
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    membership.update!(
      new_config_from: Date.current,
      alternate_depot_id: nil,
      alternate_delivery_cycle_id: nil)

    assert_nil membership.reload.alternate_depot_price
  end

  test "alternate depot: pricing correctly sums mixed depots" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      depot: depots(:farm),
      alternate_depot: depots(:home),
      alternate_depot_price: 9,
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    # farm depot_price=0 for 10 Monday baskets, home depot_price=9 for 10 Thursday baskets
    assert_equal 90, membership.depots_price
  end

  test "alternate depot: member_update! re-applies alternate depot" do
    travel_to "2024-01-01"
    org(membership_depot_update_allowed: true, basket_update_limit_in_days: 1)
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      depot: depots(:farm),
      alternate_depot: depots(:home),
      alternate_depot_price: 9,
      alternate_delivery_cycle: delivery_cycles(:thursdays))

    # All Thursday baskets should be at home depot
    assert_equal 10, membership.baskets.where(depot_id: home_id).count

    travel_to membership.baskets.last.delivery.date - 8.days
    membership.member_update!(depot_id: bakery_id)

    membership.reload
    # Main depot changed to bakery
    assert_equal bakery_id, membership.depot_id

    # Updatable Thursday baskets should still be at alternate depot (home)
    updatable_thursday_baskets = membership.baskets.includes(:delivery).select(&:can_member_update?).select { |b|
      delivery_cycles(:thursdays).include_delivery?(b.delivery)
    }
    updatable_thursday_baskets.each do |b|
      assert_equal home_id, b.depot_id
    end

    # Updatable Monday baskets should be at new main depot (bakery)
    updatable_monday_baskets = membership.baskets.includes(:delivery).select(&:can_member_update?).reject { |b|
      delivery_cycles(:thursdays).include_delivery?(b.delivery)
    }
    updatable_monday_baskets.each do |b|
      assert_equal bakery_id, b.depot_id
    end
  end

  test "basket shift survives depot-only config change and quantities are reapplied" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source_basket = baskets(:jane_5) # absent basket (thursday_5)
    target_basket = baskets(:jane_6) # future basket (thursday_6)

    # Create a shift: source (absent) → target
    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source_basket.delivery,
      target_delivery: target_basket.delivery)

    assert_equal 0, source_basket.reload.quantity
    assert_equal 2, target_basket.reload.quantity # 1 original + 1 shifted

    source_delivery = source_basket.delivery
    target_delivery = target_basket.delivery

    # Change depot — triggers config sync (destroy + recreate baskets)
    membership.update!(depot_id: farm_id, depot_price: 0)

    # Shift record survives
    assert BasketShift.exists?(shift.id)

    # New baskets exist for the same deliveries
    new_source = membership.baskets.find_by(delivery: source_delivery)
    new_target = membership.baskets.find_by(delivery: target_delivery)
    assert new_source, "source basket should be recreated"
    assert new_target, "target basket should be recreated"
    assert_equal farm_id, new_source.depot_id
    assert_equal farm_id, new_target.depot_id

    # Absence state is restored and shift quantities are reapplied
    assert new_source.absent?
    assert_equal 0, new_source.quantity
    assert_equal 2, new_target.quantity # 1 original + 1 shifted
  end

  test "basket shift adapts to new basket_size and quantities are reapplied" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source_basket = baskets(:jane_5) # absent basket (thursday_5)
    target_basket = baskets(:jane_6) # future basket (thursday_6)

    old_basket_size_id = membership.basket_size_id

    # Create a shift: source (absent) → target
    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source_basket.delivery,
      target_delivery: target_basket.delivery)

    # Shift quantities reference old basket_size
    assert_equal({ old_basket_size_id => 1 }, shift.quantities[:basket_size])

    source_delivery = source_basket.delivery
    target_delivery = target_basket.delivery

    # Change basket_size — shift adapts to new config
    membership.update!(basket_size_id: small_id, basket_size_price: 10)

    # Shift record survives
    assert BasketShift.exists?(shift.id)

    # Shift quantities are re-snapshotted with new basket_size
    shift.reload
    assert_equal({ small_id => 1 }, shift.quantities[:basket_size])

    # New baskets have the new basket_size
    new_source = membership.baskets.find_by(delivery: source_delivery)
    new_target = membership.baskets.find_by(delivery: target_delivery)
    assert_equal small_id, new_source.basket_size_id
    assert_equal small_id, new_target.basket_size_id

    # Shift quantities are reapplied with new basket_size
    assert new_source.absent?
    assert_equal 0, new_source.quantity
    assert_equal 2, new_target.quantity # 1 original + 1 shifted
  end

  test "basket shift adapts to new basket_complements and quantities are reapplied" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source_basket = baskets(:jane_5) # absent basket (thursday_5)
    target_basket = baskets(:jane_6) # future basket (thursday_6)

    # Jane subscribes to bread; verify both baskets have it
    assert_equal [ bread_id ], source_basket.complement_ids
    assert_equal [ bread_id ], target_basket.complement_ids

    # Create a shift: source (absent) → target
    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source_basket.delivery,
      target_delivery: target_basket.delivery)

    # Shift quantities reference bread complement
    assert_equal({ bread_id => 1 }, shift.quantities[:basket_complements])

    # Target complement quantity is incremented (1 original + 1 shifted)
    assert_equal 2, target_basket.reload.baskets_basket_complements.find_by(basket_complement_id: bread_id).quantity

    source_delivery = source_basket.delivery
    target_delivery = target_basket.delivery

    # Change complements: drop bread, add eggs
    complements = membership.memberships_basket_complements
    membership.update!(memberships_basket_complements_attributes: {
      "0" => { id: complements.first.id, basket_complement_id: bread_id, _destroy: true },
      "1" => { basket_complement_id: eggs_id, quantity: 1 }
    })

    # Shift record survives
    assert BasketShift.exists?(shift.id)

    # Shift quantities are re-snapshotted with new complements
    shift.reload
    assert_equal({ eggs_id => 1 }, shift.quantities[:basket_complements])

    # New baskets have eggs, not bread
    new_source = membership.baskets.find_by(delivery: source_delivery)
    new_target = membership.baskets.find_by(delivery: target_delivery)
    assert_equal [ eggs_id ], new_source.complement_ids
    assert_equal [ eggs_id ], new_target.complement_ids

    # Shift quantities are reapplied: target eggs incremented
    assert new_source.absent?
    source_eggs = new_source.baskets_basket_complements.find_by(basket_complement_id: eggs_id)
    target_eggs = new_target.baskets_basket_complements.find_by(basket_complement_id: eggs_id)
    assert_equal 0, source_eggs.quantity
    assert_equal 2, target_eggs.quantity # 1 original + 1 shifted
  end

  test "basket shift reapplied when source is before new_config_from and target is after" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    source_basket = baskets(:jane_5) # absent basket (thursday_5 = 2024-05-02)
    target_basket = baskets(:jane_8) # normal basket (thursday_8 = 2024-05-23)

    old_basket_size_id = membership.basket_size_id

    # Create a shift: source (absent) → target
    shift = BasketShift.create!(
      absence: absences(:jane_thursday_5),
      membership: membership,
      source_delivery: source_basket.delivery,
      target_delivery: target_basket.delivery)

    assert_equal({ old_basket_size_id => 1 }, shift.quantities[:basket_size])
    assert_equal 0, source_basket.reload.quantity
    assert_equal 2, target_basket.reload.quantity # 1 original + 1 shifted

    source_delivery = source_basket.delivery
    target_delivery = target_basket.delivery

    # Change basket_size starting from thursday_7 (2024-05-16)
    # Source (thursday_5 = 2024-05-02) is BEFORE new_config_from → not recreated
    # Target (thursday_8 = 2024-05-23) is AFTER new_config_from → recreated as small
    membership.update!(
      new_config_from: deliveries(:thursday_7).date,
      basket_size_id: small_id,
      basket_size_price: 10)

    # Shift record survives
    assert BasketShift.exists?(shift.id)

    # Shift quantities are NOT re-snapshotted (source wasn't recreated)
    shift.reload
    assert_equal({ old_basket_size_id => 1 }, shift.quantities[:basket_size])

    # Source basket is unchanged (before new_config_from)
    new_source = membership.baskets.find_by(delivery: source_delivery)
    assert_equal old_basket_size_id, new_source.basket_size_id
    assert new_source.absent?
    assert_equal 0, new_source.quantity

    # Target basket has new basket_size but shift quantity is still applied
    new_target = membership.baskets.find_by(delivery: target_delivery)
    assert_equal small_id, new_target.basket_size_id
    assert_equal 2, new_target.quantity # 1 original + 1 shifted
  end
end

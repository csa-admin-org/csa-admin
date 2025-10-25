# frozen_string_literal: true

require "test_helper"

class MembershipTest < ActiveSupport::TestCase
  test "set activity_participations_demanded_annually by default" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    membership = create_membership(basket_size: basket_sizes(:medium))

    assert_equal 5, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually using basket quantity" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    membership = create_membership(basket_size: basket_sizes(:medium), basket_quantity: 2)

    assert_equal 10, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually using basket_size and complements" do
    basket_sizes(:medium).update!(activity_participations_demanded_annually: 5)
    basket_complements(:bread).update!(activity_participations_demanded_annually: 2)
    basket_complements(:eggs).update!(activity_participations_demanded_annually: 3)

    membership = create_membership(
      basket_size: basket_sizes(:medium),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 2 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 5 + 2 * 2 + 3, membership.activity_participations_demanded_annually
  end

  test "set activity_participations_demanded_annually when overridden" do
    membership = create_membership(activity_participations_demanded_annually: 12)

    assert_equal 12, membership.activity_participations_demanded_annually
  end

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

  test "prevents date modification when renewed" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.renewed_at = 2024-12-10
    membership.ended_on = "2024-12-15"

    assert_not membership.valid?
    assert_includes membership.errors[:ended_on], "Membership already renewed"
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
    assert_equal [ eggs_id, bread_id ], basket.complement_ids
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

  test "price from association" do
    travel_to "2024-01-01"
    delivery_cycles(:thursdays).update!(price: 2)
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      depot: depots(:bakery),
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 10 * 20, membership.basket_sizes_price
    assert_equal 10 * 4, membership.depots_price
    assert_equal 10 * (4 + 6), membership.basket_complements_price
    assert_equal 10 * 2, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 360, membership.price
  end

  test "price from association with non-billable baskets" do
    travel_to "2024-01-01"
    delivery_cycles(:thursdays).update!(
      price: 2,
      absences_included_annually: 2)
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      depot: depots(:bakery),
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 },
        "1" => { basket_complement_id: eggs_id, quantity: 1 }
      })

    assert_equal 8 * 20, membership.basket_sizes_price
    assert_equal 8 * 4, membership.depots_price
    assert_equal 8 * (4 + 6), membership.basket_complements_price
    assert_equal 8 * 2, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 288, membership.price
  end

  test "price with custom prices and quantity" do
    travel_to "2024-01-01"
    membership = create_membership(
      basket_size: basket_sizes(:medium),
      basket_size_price: 21,
      basket_quantity: 2,
      depot: depots(:bakery),
      depot_price: 3,
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, price: "3.5", quantity: 3 },
        "1" => { basket_complement_id: eggs_id, price: "6.1", quantity: 2 }
      }
    )

    assert_equal 20 * 21, membership.basket_sizes_price
    assert_equal 20 * 3, membership.depots_price
    assert_equal 10 * (3 * 3.5 + 2 * 6.1), membership.basket_complements_price
    assert_equal 0, membership.deliveries_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 707, membership.price
  end

  test "with baskets_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      baskets_annual_price_change: -11)

    assert_equal(-11, membership.baskets_annual_price_change)
    assert_equal 100 - 11, membership.price
  end

  test "with custom basket dynamic extra price" do
    travel_to "2024-01-01"
    membership = create_membership(
      basket_price_extra: 3)

    assert_equal 10 * 3, membership.baskets_price_extra
    assert_equal 130, membership.price
  end

  test "with basket complement with deliveries cycle" do
    travel_to "2024-01-01"
    delivery_cycles(:thursdays).update!(results: :odd)
    membership = create_membership(
      delivery_cycle: delivery_cycles(:all),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1, delivery_cycle: delivery_cycles(:thursdays) }
      }
    )

    assert_equal 20 * 10, membership.basket_sizes_price
    assert_equal 5 * 4, membership.basket_complements_price
    assert_equal 220, membership.price
  end

  test "with basket_complements_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      delivery_cycle: delivery_cycles(:thursdays),
      memberships_basket_complements_attributes: {
        "0" => { basket_complement_id: bread_id, quantity: 1 }
      },
      basket_complements_annual_price_change: -10
    )

    assert_equal 10 * 10, membership.basket_sizes_price
    assert_equal 10 * 4, membership.basket_complements_price
    assert_equal(-10, membership.basket_complements_annual_price_change)
    assert_equal 130, membership.price
  end

  test "with activity_participations_annual_price_change price" do
    travel_to "2024-01-01"
    membership = create_membership(
      activity_participations_annual_price_change: -90)

    assert_equal(-90, membership.activity_participations_annual_price_change)
    assert_equal 10, membership.price
  end

  test "salary basket prices" do
    travel_to "2024-01-01"
    members(:john).update!(salary_basket: true)
    membership = memberships(:john)

    assert_equal 0, membership.basket_sizes_price
    assert_equal 0, membership.basket_complements_price
    assert_equal 0, membership.depots_price
    assert_equal 0, membership.activity_participations_annual_price_change
    assert_equal 0, membership.price
  end

  test "activity_participations_missing with active membership with no activity participations" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_equal 2, membership.activity_participations_missing
  end

  test "activity_participations_missing when in trial period with deliveries count 2" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.send(:update_member_and_baskets!)

    assert membership.trial?
    assert_not membership.trial_only?
    assert_equal 0, membership.activity_participations_missing
  end

  test "activity_participations_missing when in trial period with specific dates" do
    travel_to "2024-05-01"
    member = members(:mary)
    member.update!(trial_baskets_count: 5)
    membership = create_membership(
      member: member,
      started_on: "2024-04-01",
      ended_on: "2024-04-30")

    assert_not membership.trial?
    assert membership.trial_only?
    assert_equal 0, membership.activity_participations_missing
  end

  test "sets renew to true on create and false on update" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-31")
    assert membership.renew

    membership.reload
    membership.update!(ended_on: "2024-12-30")
    assert_not membership.renew
  end

  test "sets renew to false on create and true on update" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-30")
    assert_not membership.renew

    membership.reload
    membership.update!(ended_on: "2024-12-31")
    assert membership.renew
  end

  test "sets renew to false when changed manually" do
    travel_to "2024-01-01"
    membership = create_membership(ended_on: "2024-12-31")
    assert membership.renew

    membership.reload
    membership.update!(renew: false)
    assert_not membership.renew
  end

  test "set_activity_participations when activity participations are overridden" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 0,
      activity_participations_annual_price_change: 180)

    assert_equal 0, membership.activity_participations_demanded
    assert_equal 180, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations when activity participations are default" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 3)

    assert_equal 0, membership.activity_participations_demanded_diff_from_default
    assert_equal 3, membership.activity_participations_demanded
    assert_equal 0, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations when doing more than demanded" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: nil)

    assert_equal 2, membership.activity_participations_demanded_diff_from_default
    assert_equal 5, membership.activity_participations_demanded
    assert_equal(-(2 * 50), membership.activity_participations_annual_price_change)
  end

  test "set_activity_participations when doing less than demanded" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 1,
      activity_participations_annual_price_change: nil)

    assert_equal(-2, membership.activity_participations_demanded_diff_from_default)
    assert_equal 1, membership.activity_participations_demanded
    assert_equal 2 * 50, membership.activity_participations_annual_price_change
  end

  test "set_activity_participations with a diff from default but price change overridden" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(
      activity_participations_demanded_annually: 5,
      activity_participations_annual_price_change: -120)

    assert_equal 2, membership.activity_participations_demanded_diff_from_default
    assert_equal 5, membership.activity_participations_demanded
    assert_equal(-120, membership.activity_participations_annual_price_change)
  end

  test "set_activity_participations when activity feature is disabled" do
    travel_to "2024-01-01"
    org(features: [])
    membership = memberships(:jane)
    membership.update!(
      activity_participations_annual_price_change: nil,
      activity_participations_demanded: nil)

    assert_equal 0, membership.activity_participations_demanded_diff_from_default
    assert_equal 0, membership.activity_participations_demanded
    assert_equal 0, membership.activity_participations_annual_price_change
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

    assert_equal [
      [],
      [ bread_id ],
      [ eggs_id, bread_id ],
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

  test "updates absent baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:john)

    first_basket = membership.baskets.first
    assert_equal "normal", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert second_basket.billable
  end

  test "updates trial and absent baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2, absences_billed: true)
    create_absence(
      member: members(:jane),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:jane)
    membership.reload

    first_basket = membership.baskets.first
    assert_equal "trial", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert second_basket.billable
    third_basket = membership.baskets.third
    assert_equal "trial", third_basket.state
    assert third_basket.billable
    fourth_basket = membership.baskets.fourth
    assert_equal "normal", fourth_basket.state
    assert fourth_basket.billable
  end

  test "marks absent baskets as not billable" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: false)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-15")
    membership = memberships(:john)

    first_basket = membership.baskets.first
    assert_equal "normal", first_basket.state
    assert first_basket.billable
    second_basket = membership.baskets.second
    assert_equal "absent", second_basket.state
    assert_not second_basket.billable
  end

  test "mark last baskets are absent when all included absence aren't used yet" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-12")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3)

    assert_equal [
      [ "normal", true ],
      [ "absent", false ],
      *[ [ "normal", true ] ] * 6,
      [ "absent", false ],
      [ "absent", false ]
    ], membership.baskets.map { |b| [ b.state, b.billable ] }
  end

  test "mark last baskets are absent when all included absence aren't used yet (with basket_price_extra)" do
    travel_to "2024-01-01"
    org(features: [ :basket_price_extra, :absence ], trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-12")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3, basket_price_extra: 1)

    assert_equal [
      [ "normal", true, 1 ],
      [ "absent", false, 0 ],
      *[ [ "normal", true, 1 ] ] * 6,
      [ "absent", false, 0 ],
      [ "absent", false, 0 ]
    ], membership.baskets.map { |b| [ b.state, b.billable, b.calculated_price_extra.to_i ] }
  end

  test "mark last baskets are absent when all included absence aren't used yet with extended absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    create_absence(
      member: members(:john),
      started_on: "2024-04-05",
      ended_on: "2024-04-29")
    membership = memberships(:john)
    membership.update!(absences_included_annually: 3)

    assert_equal [
      [ "normal", true ],
      [ "absent", false ],
      [ "absent", false ],
      [ "absent", false ],
      [ "absent", true ],
      *[ [ "normal", true ] ] * 5
    ], membership.baskets.map { |b| [ b.state, b.billable ] }
  end

  test "mark_renewal_as_pending! sets renew to true when previously canceled" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.cancel!

    assert_changes -> { membership.reload.renew }, from: false, to: true do
      membership.mark_renewal_as_pending!
    end

    assert membership.renewal_pending?
  end

  test "open_renewal! requires future deliveries to be present" do
    travel_to "2025-01-01"
    mail_templates(:membership_renewal).update!(active: true)
    membership = memberships(:john_future)

    assert_raises(MembershipRenewal::MissingDeliveriesError) do
      membership.open_renewal!
    end
  end

  test "open_renewal! sets renewal_opened_at and sends member-renewal email template" do
    travel_to "2024-01-01"
    mail_templates(:membership_renewal).update!(active: true)
    membership = memberships(:jane)

    assert_difference -> { MembershipMailer.deliveries.size }, 1 do
      assert_changes -> { membership.reload.renewal_opened_at }, from: nil do
        membership.open_renewal!
        perform_enqueued_jobs
      end
    end

    assert membership.renewal_opened?
    mail = MembershipMailer.deliveries.last
    assert_equal "Renew your membership", mail.subject
  end

  test "renew sets renewal_note attrs" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_difference -> { Membership.count } do
      membership.renew!(renewal_note: "I am very happy")
    end

    membership.reload
    assert membership.renewed?
    assert_equal "I am very happy", membership.renewal_note
  end

  test "cancel sets the membership renew to false" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update_column(:renewal_opened_at, Time.current)

    assert_no_difference -> { Membership.count } do
      membership.cancel!
    end

    membership.reload
    assert membership.canceled?
    assert_not membership.renew
    assert_nil membership.renewal_opened_at
    assert_nil membership.renewed_at
  end

  test "cancel cancels the membership with a renewal_note" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_no_difference -> { Membership.count } do
      membership.cancel!(renewal_note: "I am not happy")
    end

    membership.reload
    assert membership.canceled?
    assert_equal "I am not happy", membership.renewal_note
  end

  test "cancel cancels the membership with a renewal_annual_fee" do
    travel_to "2024-01-01"
    membership = memberships(:jane)

    assert_no_difference -> { Membership.count } do
      membership.cancel!(renewal_annual_fee: "1")
    end

    membership.reload
    assert membership.canceled?
    assert_equal 30, membership.renewal_annual_fee
  end

  test "update_renewal_of_previous_membership_after_creation" do
    travel_to "2024-01-01"
    membership = memberships(:jane)
    membership.update!(renew: true, renewal_opened_at: 1.year.ago)

    travel_to "2025-01-01"
    assert_changes -> { membership.reload.renewal_state }, from: :renewal_opened, to: :renewed do
      create_membership(member: members(:jane))
    end
  end

  test "update_renewal_of_previous_membership_after_deletion clears renewed_at when renewed membership is destroyed" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { membership.reload.renewed_at }, to: nil do
      renewed_membership.destroy!
    end
  end

  test "update_renewal_of_previous_membership_after_deletion cancels previous membership when renewed membership is destroyed and in new fiscal" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { membership.reload.renewed_at }, to: nil do
      assert_changes -> { membership.reload.renew }, to: false do
        travel_to renewed_membership.started_on do
          renewed_membership.destroy!
        end
      end
    end
  end

  test "keep_renewed_membership_up_to_date! updates renewed membership" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    renewed_membership = memberships(:john_future)

    assert_changes -> { renewed_membership.reload.billing_year_division }, from: 1, to: 4 do
      membership.update!(billing_year_division: 4)
    end
  end

  test "delete_bidding_round_pledge_on_basket_size_change!" do
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

  test "#cancel_overcharged_invoice! membership period is reduced" do
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)
    membership.update!(billing_year_division: 1)

    travel_to "2024-05-01"
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    membership.reload.update!(ended_on: "2024-05-15")

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
      perform_enqueued_jobs
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! only cancel the over-paid invoices" do
    member = members(:jane)
    membership = memberships(:jane)

    travel_to "2024-01-01"
    invoice_1 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2024-04-01"
    invoice_2 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2024-07-01"
    invoice_3 = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    membership.update!(baskets_annual_price_change: -250)

    assert_difference -> { membership.reload.invoices_amount }, -invoice_2.amount - invoice_3.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice_2.reload.state
    assert_equal "canceled", invoice_3.reload.state
    assert_equal "open", invoice_1.reload.state
  end

  test "#cancel_overcharged_invoice! membership basket size price is reduced" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    membership.baskets.first.update!(basket_size_price: 29)

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! new absent basket not billed are updated" do
    travel_to "2024-01-01"
    org(absences_billed: false)
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    last_basket = membership.baskets.last
    assert_difference -> { membership.baskets.billable.count }, -1 do
      create_absence(
        member: member,
        started_on: last_basket.delivery.date - 1.day,
        ended_on: last_basket.delivery.date + 1.day)
    end
    assert_not last_basket.reload.billable

    assert_difference -> { membership.reload.invoices_amount }, -invoice.amount do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "canceled", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! past membership period is not reduced" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    travel_to "2025-01-01"
    membership.baskets.first.update!(basket_size_price: 29)

    assert_no_difference -> { membership.reload.invoices_amount } do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "open", invoice.reload.state
  end

  test "#cancel_overcharged_invoice! basket complement is added with extra price difference" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(annual_fee: 0)
    membership = memberships(:jane)

    membership.update!(billing_year_division: 1)
    invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    membership.reload
    membership.update!(memberships_basket_complements_attributes: {
      "1" => { basket_complement_id: eggs_id, quantity: 1 }
    })

    assert_no_difference -> { membership.reload.invoices_amount } do
      membership.cancel_overcharged_invoice!
    end
    assert_equal "open", invoice.reload.state
  end

  test "#destroy_or_cancel_invoices! cancel or destroy membership invoices on destroy" do
    org(billing_year_divisions: [ 12 ])
    mail_templates(:invoice_created)
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = memberships(:jane)
    membership.update_column(:billing_year_division, 12)

    travel_to "2024-01-01"
    sent_invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    travel_to "2024-02-01"
    not_sent_invoice = force_invoice(member, send_email: false)
    perform_enqueued_jobs

    travel_to "2024-03-01"
    assert_difference -> { Invoice.not_canceled.reload.count }, -2 do
      membership.destroy
    end
    assert_equal "canceled", sent_invoice.reload.state
    assert_raises(ActiveRecord::RecordNotFound) { not_sent_invoice.reload }
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
end

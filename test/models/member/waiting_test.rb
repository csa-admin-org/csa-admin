# frozen_string_literal: true

require "test_helper"

class Member::WaitingTest < ActiveSupport::TestCase
  test "sets first organization billing_year_divisions by default" do
    Current.org.billing_year_divisions = [ 4, 12 ]
    member = members(:aria)
    member.update(waiting_billing_year_division: nil)

    assert_equal 12, member.waiting_billing_year_division
  end

  test "sets last organization billing_year_divisions by default" do
    Current.org.billing_year_divisions = [ 4, 12 ]
    member = members(:aria)
    member.update(waiting_billing_year_division: 1)

    assert_equal 12, member.waiting_billing_year_division
  end

  test "only accepts organization billing_year_divisions" do
    Current.org.billing_year_divisions = [ 1, 12 ]
    member = members(:aria)

    member.update(waiting_billing_year_division: 3)
    assert_equal 12, member.waiting_billing_year_division

    member.update(waiting_billing_year_division: 1)
    assert member.save!
  end

  test "validates waiting_basket_size presence when a depot is set" do
    member = build_member(
      waiting_basket_size: nil,
      waiting_depot: depots(:farm))

    assert_not member.valid?
    assert_includes member.errors[:waiting_basket_size_id], "can't be blank"
  end

  test "validates waiting_basket_size_id presence on public create in membership mode" do
    member = build_member(public_create: true, waiting_basket_size_id: nil)

    assert_not member.valid?
    assert_includes member.errors[:waiting_basket_size_id], "can't be blank"

    member.waiting_basket_size_id = 0
    assert member.valid?

    BasketSize.update_all(visible: false)
    member.waiting_basket_size_id = nil
    assert member.valid?
  end

  test "validates waiting_basket_size_id not required on public create in shop mode" do
    org(member_form_mode: "shop")
    member = build_member(public_create: true, waiting_basket_size_id: nil, shop_depot_id: depots(:farm).id)

    assert member.valid?
  end

  test "allows blank waiting_basket_price_extra" do
    member = build_member(
      public_create: true,
      waiting_basket_size: basket_sizes(:small),
      waiting_depot: depots(:farm),
      waiting_delivery_cycle: delivery_cycles(:mondays),
      waiting_basket_price_extra: nil)

    assert member.valid?
  end

  test "validates waiting_depot presence" do
    member = build_member(
      waiting_basket_size: basket_sizes(:small),
      waiting_depot: nil)

    assert_not member.valid?
    assert_includes member.errors[:waiting_depot_id], "can't be blank"
  end

  test "validates waiting_membership_started_on presence for admin create when waiting list is disabled" do
    org(features: Current.org.features - [ :waiting_list ])
    member = build_member(
      waiting_basket_size: basket_sizes(:small),
      waiting_depot: depots(:farm))

    assert_not member.valid?
    assert_includes member.errors[:waiting_membership_started_on], "can't be blank"

    member.waiting_membership_started_on = Date.current
    assert member.valid?
  end

  test "validates waiting_activity_participations_demanded_annually on public create" do
    member = build_member(
      waiting_activity_participations_demanded_annually: nil,
      waiting_basket_size_id: 0,
      public_create: true)

    org(activity_participations_form_min: 2)
    member.update(waiting_activity_participations_demanded_annually: 1)
    assert_not member.valid?
    member.update(waiting_activity_participations_demanded_annually: 2)
    assert member.valid?

    org(activity_participations_form_max: 4)
    member.update(waiting_activity_participations_demanded_annually: 5)
    assert_not member.valid?
    member.update(waiting_activity_participations_demanded_annually: 4)
    assert member.valid?
    member.update(waiting_activity_participations_demanded_annually: 3)
    assert member.valid?
  end

  test "set_default_waiting_delivery_cycle" do
    travel_to "2024-01-01"
    member = members(:aria)
    member.update!(waiting_delivery_cycle_id: nil)

    assert_equal delivery_cycles(:all), member.waiting_delivery_cycle
  end

  test "inactive member with complete waiting request moves to waiting on save" do
    member = members(:mary)

    assert_changes -> { member.state }, from: "inactive", to: "waiting" do
      member.update!(
        waiting_basket_size: basket_sizes(:small),
        waiting_depot: depots(:farm),
        waiting_delivery_cycle: delivery_cycles(:mondays),
        waiting_billing_year_division: 1)
    end
    assert member.waiting_started_at > 1.minute.ago
    assert_equal 30, member.annual_fee
  end

  test "inactive member with complete waiting request ignores direct start date and moves to waiting" do
    member = members(:mary)

    assert_changes -> { member.state }, from: "inactive", to: "waiting" do
      member.update!(
        waiting_membership_started_on: Date.current,
        waiting_basket_size: basket_sizes(:small),
        waiting_depot: depots(:farm),
        waiting_delivery_cycle: delivery_cycles(:mondays),
        waiting_billing_year_division: 1)
    end
    assert member.waiting_started_at > 1.minute.ago
  end

  test "inactive member with partial waiting request is invalid" do
    member = members(:mary)

    assert_not member.update(waiting_basket_size: basket_sizes(:small))
    assert_includes member.errors[:waiting_depot], "can't be blank"
    assert_includes member.errors[:waiting_delivery_cycle], "can't be blank"
    assert member.reload.inactive?
  end

  test "can_create_membership? returns true for waiting member with complete waiting data" do
    travel_to "2024-05-01"

    member = Member.new(
      state: "waiting",
      waiting_basket_size_id: basket_sizes(:medium).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_basket_price_extra: 0,
      waiting_activity_participations_demanded_annually: 0,
      waiting_billing_year_division: 1)
    assert member.can_create_membership?
  end

  test "can_create_membership? returns true when optional waiting values are blank" do
    travel_to "2024-05-01"

    member = Member.new(
      state: "waiting",
      waiting_basket_size_id: basket_sizes(:medium).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil,
      waiting_billing_year_division: 1)
    assert member.can_create_membership?
  end

  test "can_create_membership? returns false if any required waiting id is missing" do
    travel_to "2024-05-01"

    base = {
      state: "waiting",
      waiting_basket_size_id: basket_sizes(:medium).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_billing_year_division: 1
    }
    assert_not Member.new(base.merge(waiting_basket_size_id: nil)).can_create_membership?
    assert_not Member.new(base.merge(waiting_depot_id: nil)).can_create_membership?
    assert_not Member.new(base.merge(waiting_delivery_cycle_id: nil)).can_create_membership?
    assert_not Member.new(base.merge(waiting_billing_year_division: nil)).can_create_membership?
    assert_not Member.new(state: "waiting").can_create_membership?
  end

  test "can_create_membership? returns false for non-waiting members" do
    travel_to "2024-05-01"

    member = Member.new(
      state: "active",
      waiting_basket_size_id: basket_sizes(:medium).id,
      waiting_depot_id: depots(:farm).id,
      waiting_delivery_cycle_id: delivery_cycles(:mondays).id,
      waiting_basket_price_extra: 0,
      waiting_activity_participations_demanded_annually: 0,
      waiting_billing_year_division: 1)
    assert_not member.can_create_membership?
  end

  test "create_membership_from_waiting_request! uses selected delivery cycle next delivery week" do
    travel_to "2024-05-01"
    member = members(:aria)

    membership = member.create_membership_from_waiting_request!

    assert_equal Date.new(2024, 5, 6), membership.started_on
    assert member.reload.active?
  end

  test "create_membership_from_waiting_request! uses defaults for blank optional waiting values" do
    travel_to "2024-05-01"
    member = members(:aria)
    member.update!(
      waiting_basket_price_extra: nil,
      waiting_activity_participations_demanded_annually: nil)

    membership = member.create_membership_from_waiting_request!

    assert_equal 0, membership.basket_price_extra
    assert_equal membership.activity_participations_demanded_annually_by_default,
      membership.activity_participations_demanded_annually
  end
end

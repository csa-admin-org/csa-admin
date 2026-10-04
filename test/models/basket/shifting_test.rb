# frozen_string_literal: true

require "test_helper"

class Basket::ShiftingTest < ActiveSupport::TestCase
  test "can_be_shifted? returns true for absent billable basket" do
    basket = baskets(:jane_5)

    assert basket.absent?
    assert basket.billable?
    assert_not basket.empty?
    assert_not basket.shifted?
    assert basket.can_be_shifted?
  end

  test "can_be_shifted? returns true for definite included absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)
    basket = membership.baskets.second
    create_absence(
      member: membership.member,
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date + 1.day)
    basket.reload

    assert basket.absent?
    assert basket.absence_id?
    assert_not basket.billable?
    assert basket.can_be_shifted?
  end

  test "can_be_admin_shifted? is true for a billed present basket and false when empty" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true, features: [ :absence ])
    basket = memberships(:john).baskets.normal.first

    assert basket.billable?
    assert_not basket.absent?
    assert basket.can_be_admin_shifted?

    basket.update_columns(quantity: 0)
    assert_equal :empty, basket.admin_shift_block_reason
    assert_not basket.can_be_admin_shifted?
  end

  test "can_be_shifted? returns false for non-absent basket" do
    basket = baskets(:jane_6)

    assert_not basket.absent?
    assert basket.billable?
    assert_not basket.can_be_shifted?
  end

  test "can_be_shifted? returns false for empty absent basket" do
    basket = baskets(:jane_5)
    basket.update_columns(quantity: 0)
    basket.baskets_basket_complements.delete_all

    assert basket.absent?
    assert basket.billable?
    assert_empty basket
    assert_not basket.can_be_shifted?
  end

  test "can_be_member_shifted? returns true for definite included absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true, basket_shifts_annually: 1)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)
    basket = membership.baskets.second
    create_absence(
      member: membership.member,
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date + 1.day)
    basket.reload

    assert_not basket.billable?
    assert basket.can_be_member_shifted?
  end

  test "can_be_shifted? returns false for provisional absence" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: true)
    membership = memberships(:john)
    membership.update!(absences_included_annually: 1)
    basket = membership.baskets.last

    assert basket.provisionally_absent?
    assert_not basket.billable?
    assert_not basket.can_be_shifted?
  end

  test "can_be_shifted? returns false when absences are not billed" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0, absences_billed: false)
    membership = memberships(:john)
    basket = membership.baskets.second
    create_absence(
      member: membership.member,
      started_on: basket.delivery.date,
      ended_on: basket.delivery.date + 1.day)
    basket.reload

    assert basket.absent?
    assert basket.absence_id?
    assert_not basket.billable?
    assert_not basket.can_be_shifted?
  end

  test "content_forfeited? returns true for non-billable absent basket" do
    basket = baskets(:jane_5)
    basket.update_column(:billable, false)

    assert basket.absent?
    assert_not basket.billable?
    assert basket.content_forfeited?
  end

  test "content_forfeited? returns true for empty absent basket" do
    basket = baskets(:jane_5)
    basket.update_columns(quantity: 0)
    basket.baskets_basket_complements.delete_all

    assert basket.absent?
    assert basket.billable?
    assert_empty basket
    assert basket.content_forfeited?
  end

  test "content_forfeited? returns false for billable non-empty absent basket" do
    basket = baskets(:jane_5)

    assert basket.absent?
    assert basket.billable?
    assert_not basket.empty?
    assert_not basket.content_forfeited?
  end

  test "content_forfeited? returns true for shifted basket (empty on source date)" do
    basket = baskets(:jane_5)
    basket.update!(shift_target_basket_id: baskets(:jane_8).id)
    basket.reload

    assert basket.absent?
    assert basket.shifted?
    assert_empty basket, "shifted basket is empty (quantity decremented)"
    assert basket.content_forfeited?, "shifted basket is forfeited on source date (nothing delivered here)"
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
    reset_member_shift_memos!(basket)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7),
      baskets(:jane_8),
      baskets(:jane_9),
      baskets(:jane_10)
    ], basket.member_shiftable_basket_targets

    org(basket_shift_deadline_in_weeks: 2)
    reset_member_shift_memos!(basket)
    assert_equal [
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets

    travel_to basket.delivery.date - 2.weeks
    reset_member_shift_memos!(basket)
    assert_equal [
      baskets(:jane_4),
      baskets(:jane_6),
      baskets(:jane_7)
    ], basket.member_shiftable_basket_targets
  end

  test "#member_shiftable_basket_targets excludes incompatible candidates" do
    org(basket_shifts_annually: nil, basket_shift_deadline_in_weeks: nil)
    basket = baskets(:jane_5)
    travel_to baskets(:jane_4).delivery.date
    create_absence(
      member: members(:jane),
      started_on: baskets(:jane_4).delivery.date,
      ended_on: baskets(:jane_4).delivery.date)
    earlier = baskets(:jane_4).reload
    BasketShift.create!(
      absence: earlier.absence,
      membership: earlier.membership,
      source_delivery: earlier.delivery,
      target_delivery: baskets(:jane_8).delivery)

    travel_to basket.delivery.date
    baskets(:jane_6).update_columns(basket_size_id: basket_sizes(:medium).id)
    baskets(:jane_7).baskets_basket_complements.delete_all

    assert_equal [ baskets(:jane_9), baskets(:jane_10) ], basket.reload.member_shiftable_basket_targets
  end

  test "#member_shiftable_basket_targets is memoized for the request" do
    org(basket_shifts_annually: 1, basket_shift_deadline_in_weeks: nil)
    basket = baskets(:jane_5)
    travel_to basket.delivery.date

    assert basket.can_be_member_shifted?
    expected = [
      baskets(:jane_6),
      baskets(:jane_7),
      baskets(:jane_8),
      baskets(:jane_9),
      baskets(:jane_10)
    ]
    assert_equal expected, basket.member_shiftable_basket_targets

    queries = collect_sql_queries { basket.member_shiftable_basket_targets }

    assert_empty queries
    assert_equal expected, basket.member_shiftable_basket_targets
  end

  test "#member_shiftable_basket_targets does not query per candidate" do
    org(basket_shifts_annually: 1, basket_shift_deadline_in_weeks: nil)
    basket = baskets(:jane_5)
    travel_to basket.delivery.date

    names = collect_sql_query_names {
      assert_equal 5, basket.member_shiftable_basket_targets.size
    }

    assert_empty names.grep(/Basket Exists/), names.inspect
    assert_empty names.grep(/\ABasketComplement /), names.inspect
    assert_empty names.grep(/BasketShift Exists/), names.inspect
    assert_operator names.count("Basket Load") + names.count("Basket Eager Load"), :<=, 1
    assert_operator names.count("BasketsBasketComplement Load"), :<=, 1
    assert_operator names.count("BasketsBasketComplement Sum"), :<=, 1
    assert_operator names.count("BasketsBasketComplement Pluck"), :<=, 1
  end

  test "#member_shiftable_basket_targets query count stays bounded as candidates grow" do
    org(basket_shifts_annually: 1, basket_shift_deadline_in_weeks: nil)
    membership = memberships(:jane)
    basket = baskets(:jane_5)
    travel_to basket.delivery.date

    few_names = collect_sql_query_names {
      assert_equal 5, Membership.find(membership.id).baskets.find(basket.id).member_shiftable_basket_targets.size
    }
    add_coming_member_shift_candidates!(membership, 8)

    many_names = collect_sql_query_names {
      assert_equal 5, Membership.find(membership.id).baskets.find(basket.id).member_shiftable_basket_targets.size
    }

    assert_operator membership.baskets.coming.count, :>=, 13
    assert_equal few_names.tally, many_names.tally
  end

  private

  def reset_member_shift_memos!(basket)
    %i[@member_shiftable_basket_targets @member_shift_allowed_range].each do |ivar|
      basket.remove_instance_variable(ivar) if basket.instance_variable_defined?(ivar)
    end
    membership = basket.membership
    %i[@member_shift_candidates @received_shift_delivery_ids].each do |ivar|
      membership.remove_instance_variable(ivar) if membership.instance_variable_defined?(ivar)
    end
  end

  def add_coming_member_shift_candidates!(membership, count)
    template = baskets(:jane_10)
    last_date = template.delivery.date

    count.times do |i|
      delivery = Delivery.create!(date: last_date + (i + 1).weeks)
      membership.baskets.create!(
        delivery: delivery,
        basket_size: template.basket_size,
        basket_size_price: template.basket_size_price,
        depot: template.depot,
        depot_price: template.depot_price,
        delivery_cycle_price: template.delivery_cycle_price,
        quantity: template.quantity)
    end
  end

  def collect_sql_queries
    queries = []
    callback = ->(_name, _start, _finish, _id, payload) {
      sql = payload[:sql]
      queries << sql unless payload[:name] == "SCHEMA" || sql.match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end

  def collect_sql_query_names
    names = []
    callback = ->(_name, _start, _finish, _id, payload) {
      next if payload[:name] == "SCHEMA" || payload[:sql].match?(/\A(?:BEGIN|COMMIT|SAVEPOINT|RELEASE)/i)

      names << payload[:name]
    }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    names
  end
end

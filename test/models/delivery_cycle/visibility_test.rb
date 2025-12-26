# frozen_string_literal: true

require "test_helper"

class DeliveryCycle::VisibilityTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
  end

  test "visible? returns false when depots have only one cycle each" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Each depot has only one cycle - no shared depots
    mondays.depots = [ home ]
    thursdays.depots = [ farm ]
    all.depots = [ bakery ]
    bakery.update!(visible: false)

    assert_not DeliveryCycle.visible?
  end

  test "visible? returns true when at least one depot has multiple cycles" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Home depot has both cycles - shared depot
    mondays.depots = [ home, farm ]
    thursdays.depots = [ home ]
    all.depots = [ bakery ]
    bakery.update!(visible: false)

    assert DeliveryCycle.visible?
  end

  test "primary returns cycle with most depots when billable_deliveries_count is equal" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Both cycles have same deliveries count, but mondays has more depots
    mondays.depots = [ home, farm, bakery ]
    thursdays.depots = [ home ]
    all.discard

    assert_equal mondays, DeliveryCycle.primary
  end

  test "primary returns cycle with highest billable_deliveries_count regardless of depot count" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    # Mondays has more depots but fewer deliveries
    mondays.depots = [ home, farm, bakery ]
    all.depots = [ home ]
    thursdays.discard

    assert_equal all, DeliveryCycle.primary
  end

  test "primary? returns true for the primary cycle" do
    primary = DeliveryCycle.primary

    assert primary.primary?
  end

  test "primary? returns false for non-primary cycles" do
    primary = DeliveryCycle.primary
    other = DeliveryCycle.kept.where.not(id: primary.id).first

    assert_not other.primary?
  end

  test "visible? instance method returns true when depot has visible depots" do
    cycle = delivery_cycles(:mondays)
    home = depots(:home)
    cycle.depots = [ home ]

    assert cycle.visible?
  end

  test "visible? instance method returns false when no visible depots" do
    cycle = delivery_cycles(:mondays)
    bakery = depots(:bakery)
    bakery.update!(visible: false)
    cycle.depots = [ bakery ]

    assert_not cycle.visible?
  end

  def member_ordered_names
    DeliveryCycle.member_ordered.map(&:name)
  end

  test "member_ordered" do
    create_delivery_cycle(
      name: "MondaysOdd",
      wdays: [ 1 ],
      periods_attributes: [
        { from_fy_month: 1, to_fy_month: 12, results: :odd }
      ]
    )

    assert_equal %w[All Mondays Thursdays MondaysOdd], member_ordered_names

    org(delivery_cycles_member_order_mode: "deliveries_count_asc")
    assert_equal %w[MondaysOdd Mondays Thursdays All], member_ordered_names

    org(delivery_cycles_member_order_mode: "name_asc")
    assert_equal %w[All Mondays MondaysOdd Thursdays], member_ordered_names

    org(delivery_cycles_member_order_mode: "wdays_asc")
    assert_equal %w[Mondays MondaysOdd All Thursdays], member_ordered_names

    delivery_cycles(:mondays).update!(member_order_priority: 2)
    assert_equal %w[MondaysOdd All Thursdays Mondays], member_ordered_names
  end

  test "shared_depots? returns true when depots are shared across cycles" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)

    home = depots(:home)

    mondays.depots = [ home ]
    thursdays.depots = [ home ]

    assert DeliveryCycle.shared_depots?
  end

  test "shared_depots? returns false when no depots are shared" do
    mondays = delivery_cycles(:mondays)
    thursdays = delivery_cycles(:thursdays)
    all = delivery_cycles(:all)

    home = depots(:home)
    farm = depots(:farm)
    bakery = depots(:bakery)

    mondays.depots = [ home ]
    thursdays.depots = [ farm ]
    all.depots = [ bakery ]
    bakery.update!(visible: false)

    assert_not DeliveryCycle.shared_depots?
  end
end

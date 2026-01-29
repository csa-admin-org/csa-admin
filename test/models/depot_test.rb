# frozen_string_literal: true

require "test_helper"

class DepotTest < ActiveSupport::TestCase
  def member_ordered_names
    Depot.member_ordered.map(&:name)
  end

  test "member_ordered" do
    assert_equal %w[ Farm Bakery Home ], member_ordered_names

    org(depots_member_order_mode: "price_desc")
    assert_equal %w[ Home Bakery Farm], member_ordered_names

    org(depots_member_order_mode: "name_asc")
    assert_equal %w[ Bakery Home Farm ], member_ordered_names

    depots(:bakery).update!(member_order_priority: 2)
    assert_equal %w[ Home Farm Bakery], member_ordered_names
  end

  test "deliveries_count counts future deliveries when exists" do
    travel_to "2024-01-01"
    depot = depots(:farm)
    assert_changes -> { depot.reload.billable_deliveries_counts }, from: [ 10, 20 ], to: [ 10, 11, 21 ] do
      Delivery.create!(date: deliveries(:monday_future_10).date + 1.week)
    end
  end

  test "move_to moves depot to a new position" do
    travel_to "2024-01-01"
    d1 = depots(:farm)
    d2 = depots(:home)
    d3 = depots(:bakery)
    memberships(:bob).destroy!

    assert_changes -> { Depot.pluck(:id) }, from: [ d1.id, d2.id, d3.id ], to: [ d2.id, d3.id, d1.id ] do
      d1.move_to(2, deliveries(:monday_1))
    end
  end

  test "move_to moves depot to a new position with delivery context respected" do
    travel_to "2024-01-01"
    d1 = depots(:farm)
    d2 = depots(:home)
    d3 = depots(:bakery)

    assert_changes -> { Depot.pluck(:id) }, from: [ d1.id, d2.id, d3.id ], to: [ d2.id, d1.id, d3.id ] do
      d1.move_to(2, deliveries(:monday_1))
    end
  end

  def depot_member_names(depot, delivery)
    depot.baskets_for(delivery).map(&:member).map(&:name)
  end

  test "move_member_to moves member to a new position" do
    travel_to "2024-01-01"
    depot = depots(:home)
    depot.update_column(:delivery_sheets_mode, "home_delivery")
    members(:john).update!(name: "John")
    members(:jane).update!(name: "Jane")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_changes -> { depot_member_names(depot, deliveries(:monday_1)) }, from: %w[ Bob Jane John ], to: %w[ Bob John Jane ] do
      depot.move_member_to(2, members(:john), deliveries(:monday_1))
    end

    depot.update_column(:delivery_sheets_mode, "signature_sheets")
    assert_equal %w[ Bob Jane John ], depot_member_names(depot, deliveries(:monday_1))
  end

  test "move_member_to moves member to a new position with delivery context respected" do
    travel_to "2024-01-01"
    depot = depots(:home)
    depot.update_column(:delivery_sheets_mode, "home_delivery")
    members(:john).update!(name: "John")
    members(:jane).update!(name: "Jane")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_changes -> { depot_member_names(depot, deliveries(:monday_1)) }, from: %w[ Bob Jane John ], to: %w[ John Bob Jane ] do
      depot.move_member_to(1, members(:john), deliveries(:monday_1))
    end

    assert_equal %w[ John Jane ], depot_member_names(depot, deliveries(:monday_2))
  end

  test "member_sorting sorts names case and accent insensitively" do
    travel_to "2024-01-01"
    depot = depots(:home)
    members(:john).update!(name: "Élodie")
    members(:jane).update!(name: "alice")
    members(:bob).update!(name: "Bob")
    memberships(:john).update!(depot: depot)
    memberships(:jane).update!(depot: depot, delivery_cycle: delivery_cycles(:mondays))

    assert_equal %w[ alice Bob Élodie ], depot_member_names(depot, deliveries(:monday_1))
  end
end

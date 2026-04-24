# frozen_string_literal: true

require "test_helper"

class MembersHelperTest < ActionView::TestCase
  test "deliveries_count_range_with_absences scalar: shows count with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences(26, 2)
  end

  test "deliveries_count_range_with_absences scalar: no absence annotation when zero absences" do
    assert_equal "26", deliveries_count_range_with_absences(26, 0)
  end

  test "deliveries_count_range_with_absences scalar: zero count suppresses absence annotation" do
    assert_equal "0", deliveries_count_range_with_absences(0, 2)
  end

  test "deliveries_count_range_with_absences array: single value with absence" do
    assert_equal "26 (-2)", deliveries_count_range_with_absences([ 26 ], [ 2 ])
  end

  test "deliveries_count_range_with_absences array: range of counts with range of absences" do
    assert_equal "24-26 (-1-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 1, 2 ])
  end

  test "deliveries_count_range_with_absences array: uniform absence shown as single value" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 2, 2 ])
  end

  test "deliveries_count_range_with_absences array: no annotation when all absences are zero" do
    assert_equal "26", deliveries_count_range_with_absences([ 26 ], [ 0 ])
  end

  test "deliveries_count_range_with_absences array: skips zero absences in mixed cycles" do
    assert_equal "24-26 (-2)", deliveries_count_range_with_absences([ 24, 26 ], [ 0, 2 ])
  end

  test "depot_details does not show delivery count when depot has same cycles in different order" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_all, dc_thursdays, dc_mondays ]

    assert_equal(@depots_delivery_cycles.map(&:id).sort, farm.delivery_cycle_ids.sort)
    assert_equal farm.full_address, depot_details(farm)
  end

  test "depot_details shows delivery count when depot has genuinely different cycles" do
    farm = depots(:farm)
    dc_mondays = delivery_cycles(:mondays)
    dc_thursdays = delivery_cycles(:thursdays)
    dc_all = delivery_cycles(:all)

    @billable_deliveries_counts = [ 10, 20 ]
    @depots_delivery_cycles = [ dc_mondays, dc_thursdays, dc_all ]

    farm.delivery_cycle_ids = [ dc_mondays.id ]

    assert_not_equal farm.full_address, depot_details(farm)
  end
end

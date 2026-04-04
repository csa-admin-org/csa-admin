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
end

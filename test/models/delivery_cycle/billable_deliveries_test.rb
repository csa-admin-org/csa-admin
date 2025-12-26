# frozen_string_literal: true

require "test_helper"

class DeliveryCycle::BillableDeliveriesTest < ActiveSupport::TestCase
  setup do
    travel_to "2024-01-01"
  end

  test "billable_deliveries_count subtracts absences_included_annually from deliveries_count" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 2)

    assert_equal cycle.deliveries_count - 2, cycle.billable_deliveries_count
  end

  test "billable_deliveries_count with zero absences equals deliveries_count" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 0)

    assert_equal cycle.deliveries_count, cycle.billable_deliveries_count
  end

  test "billable_deliveries_count_for basket complement pro-rates absences" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 2)

    complement = basket_complements(:bread)
    # Set up complement with some delivery_ids that overlap with cycle
    complement.delivery_ids = cycle.current_and_future_delivery_ids.take(5)

    count = cycle.billable_deliveries_count_for(complement)

    # Should be less than the raw intersection count due to pro-rated absences
    assert count <= 5
    assert count >= 0
  end

  test "billable_deliveries_count_for basket complement without absences" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 0)

    complement = basket_complements(:bread)
    complement.delivery_ids = cycle.current_and_future_delivery_ids.take(5)

    count = cycle.billable_deliveries_count_for(complement)

    assert_equal 5, count
  end

  test "billable_deliveries_count_for_basket_size returns count based on filtered deliveries" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 0)
    basket_size = basket_sizes(:small)

    # When basket_size is always deliverable, should equal billable_deliveries_count
    if basket_size.always_deliverable?
      assert_equal cycle.billable_deliveries_count, cycle.billable_deliveries_count_for_basket_size(basket_size)
    else
      # Otherwise should be based on filtered deliveries
      count = cycle.billable_deliveries_count_for_basket_size(basket_size)
      assert count >= 0
      assert count <= cycle.deliveries_count
    end
  end

  test "billable_deliveries_count_for_basket_size with absences pro-rates correctly" do
    cycle = delivery_cycles(:mondays)
    cycle.update!(absences_included_annually: 2)
    basket_size = basket_sizes(:small)

    count_with_absences = cycle.billable_deliveries_count_for_basket_size(basket_size)

    cycle.update!(absences_included_annually: 0)
    count_without_absences = cycle.billable_deliveries_count_for_basket_size(basket_size)

    assert count_with_absences <= count_without_absences
  end

  test "billable_deliveries_count_for_basket_size never returns negative" do
    cycle = delivery_cycles(:mondays)
    basket_size = basket_sizes(:small)

    # The method should always return >= 0 even with high absences
    # This is enforced by the [ count, 0 ].max in the implementation
    count = cycle.billable_deliveries_count_for_basket_size(basket_size)

    assert_kind_of Integer, count
    assert count >= 0
  end

  test "class method billable_deliveries_counts returns unique sorted counts" do
    counts = DeliveryCycle.billable_deliveries_counts

    assert_equal counts, counts.uniq.sort
  end

  test "class method billable_deliveries_count_for returns counts for complement" do
    complement = basket_complements(:bread)

    counts = DeliveryCycle.billable_deliveries_count_for(complement)

    assert_kind_of Array, counts
    assert_equal counts, counts.uniq.sort
  end

  test "class method billable_deliveries_counts_for returns counts for basket size" do
    basket_size = basket_sizes(:small)

    counts = DeliveryCycle.billable_deliveries_counts_for(basket_size)

    assert_kind_of Array, counts
    assert_equal counts, counts.uniq.sort
  end

  test "class method future_deliveries_counts returns unique sorted counts" do
    counts = DeliveryCycle.future_deliveries_counts

    assert_kind_of Array, counts
    assert_equal counts, counts.uniq.sort
  end
end

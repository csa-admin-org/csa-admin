# frozen_string_literal: true

require "test_helper"

class Billing::PrevisionalInvoicingTest < ActiveSupport::TestCase
  test "annual billing with no invoices" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    assert_equal 1, membership.billing_year_division
    assert_equal 200, membership.price

    result = Billing::PrevisionalInvoicing.new(membership).compute

    assert_equal({ "2024-01" => 200.0 }, result)
    assert_sum_equals_missing membership, result
  end

  test "quarterly billing with no invoices" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal({
      "2024-01" => 50.0,
      "2024-04" => 50.0,
      "2024-07" => 50.0,
      "2024-10" => 50.0
    }, result)
    assert_sum_equals_missing membership, result
  end

  test "quarterly billing after Q1 invoice" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal({
      "2024-04" => 50.0,
      "2024-07" => 50.0,
      "2024-10" => 50.0
    }, result)
    assert_sum_equals_missing membership, result
  end

  test "quarterly billing after Q1 and Q2 invoices" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal({
      "2024-07" => 50.0,
      "2024-10" => 50.0
    }, result)
    assert_sum_equals_missing membership, result
  end

  test "monthly billing with no invoices" do
    org(billing_year_divisions: [ 1, 2, 3, 4, 12 ])
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 12)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal 12, result.size
    expected_keys = (1..12).map { |m| "2024-%02d" % m }
    assert_equal expected_keys, result.keys
    assert_sum_equals_missing membership, result
  end

  test "monthly billing after first 3 months invoiced" do
    org(billing_year_divisions: [ 1, 2, 3, 4, 12 ])
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    travel_to "2024-02-01"
    force_invoice(member)

    travel_to "2024-03-01"
    force_invoice(member)

    travel_to "2024-04-01"
    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal 9, result.size
    expected_keys = (4..12).map { |m| "2024-%02d" % m }
    assert_equal expected_keys, result.keys
    assert_sum_equals_missing membership, result
  end

  test "semi-annual billing with no invoices" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 2)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal({
      "2024-01" => 100.0,
      "2024-07" => 100.0
    }, result)
    assert_sum_equals_missing membership, result
  end

  test "fully invoiced membership returns empty hash" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    force_invoice(member)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_empty(result)
    assert_equal 0, membership.missing_invoices_amount
  end

  test "salary basket member returns empty hash" do
    travel_to "2024-01-01"
    members(:john).update!(salary_basket: true)
    membership = memberships(:john)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_empty(result)
  end

  test "no recurring billing configured returns empty hash" do
    org(recurring_billing_wday: nil)
    travel_to "2024-01-01"
    membership = memberships(:john)

    result = Billing::PrevisionalInvoicing.new(membership).compute

    assert_empty(result)
  end

  test "partial year membership ending mid-year" do
    travel_to "2024-01-01"
    membership = memberships(:bob) # ends 2024-04-05
    membership.update!(billing_year_division: 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Bob's membership ends in April (Q2), so at most Q1 and Q2 periods
    # All amounts should be within the first two quarters
    result.each_key do |key|
      month = key.split("-").last.to_i
      assert month <= 4, "Expected month <= 4, got #{month}"
    end
    assert_sum_equals_missing membership, result
  end

  test "billing_starts_after_first_delivery defers first billing month" do
    org(billing_starts_after_first_delivery: true)
    travel_to "2024-01-01"
    membership = memberships(:john)
    # John's first delivery is on a Monday in April (2024-04-01)
    assert_equal 1, membership.billing_year_division

    result = Billing::PrevisionalInvoicing.new(membership).compute

    # With annual billing and billing_starts_after_first_delivery,
    # the invoice should be projected in April (first delivery month), not January
    assert_equal 1, result.size
    assert_equal "2024-04", result.keys.first
    assert_sum_equals_missing membership, result
  end

  test "billing_starts_after_first_delivery with quarterly billing" do
    org(billing_starts_after_first_delivery: true)
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # First delivery is April 1, which falls in Q2 (Apr-Jun).
    # Q1 should be skipped since billing hasn't started yet.
    # First entry should be April.
    assert_equal "2024-04", result.keys.first
    assert_sum_equals_missing membership, result
  end

  test "billing_ends_on_last_delivery_fy_month limits periods" do
    org(billing_ends_on_last_delivery_fy_month: true)
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 4)

    # John's last delivery is in June (last Monday = 2024-06-03)
    last_delivery = membership.deliveries.last
    last_delivery_fy_month = Current.org.fy_month_for(last_delivery.date)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Should stop at the period containing the last delivery month
    result.each_key do |key|
      month = key.split("-").last.to_i
      fy_month = Current.org.fiscal_year_for(Date.new(2024, month, 1)).fy_month(Date.new(2024, month, 1))
      assert fy_month <= last_delivery_fy_month,
        "Expected fy_month <= #{last_delivery_fy_month}, got #{fy_month} for key #{key}"
    end
    assert_sum_equals_missing membership, result
  end

  test "trial membership with no billable delivery returns empty hash" do
    org(billing_starts_after_first_delivery: true)
    travel_to "2024-01-01"
    membership = memberships(:john)
    # Make all baskets unfilled so there's no billable delivery
    membership.baskets.update_all(quantity: 0)

    assert_nil membership.first_billable_delivery

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_empty(result)
  end

  test "rounding is handled correctly with non-round price" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    # Set a price that doesn't divide evenly by 4
    membership.update!(baskets_annual_price_change: 1) # price becomes 201
    membership.update!(billing_year_division: 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Last period should absorb rounding remainder
    assert_sum_equals_missing membership, result
    assert_equal 4, result.size
  end

  test "future membership projects all periods" do
    travel_to "2024-01-01"
    membership = memberships(:john_future) # starts 2025-01-01
    membership.update_column(:billing_year_division, 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal 4, result.size
    expected_keys = %w[2025-01 2025-04 2025-07 2025-10]
    assert_equal expected_keys, result.keys
    assert_sum_equals_missing membership, result
  end

  test "previsional amounts are persisted via update_price_and_invoices_amount!" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 4)

    membership.reload
    assert membership.previsional_invoicing_amounts.present?
    assert_equal 4, membership.previsional_invoicing_amounts.size
    assert_in_delta membership.missing_invoices_amount.to_f,
      membership.previsional_invoicing_amounts.values.sum, 0.01
  end

  test "previsional amounts update when invoice is created" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)

    assert_equal 4, membership.reload.previsional_invoicing_amounts.size

    force_invoice(member)
    membership.reload

    assert_equal 3, membership.previsional_invoicing_amounts.size
    assert_in_delta membership.missing_invoices_amount.to_f,
      membership.previsional_invoicing_amounts.values.sum, 0.01
  end

  test "previsional amounts update when price changes" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    membership.update!(billing_year_division: 4)

    old_amounts = membership.reload.previsional_invoicing_amounts.dup
    membership.update!(baskets_annual_price_change: -50) # reduce price by 50

    new_amounts = membership.reload.previsional_invoicing_amounts
    assert_not_equal old_amounts, new_amounts
    assert_in_delta membership.missing_invoices_amount.to_f, new_amounts.values.sum, 0.01
  end

  test "non-standard fiscal year start month with cross-year keys" do
    org(fiscal_year_start_month: 4) # Fiscal year: April 2024 → March 2025
    travel_to "2024-04-01"
    membership = create_membership(
      started_on: Date.new(2024, 4, 1),
      ended_on: Date.new(2025, 3, 31),
      billing_year_division: 4
    )

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Quarterly periods: Apr-Jun, Jul-Sep, Oct-Dec, Jan-Mar
    # Keys cross the calendar year boundary (2024 → 2025)
    assert_equal 4, result.size
    expected_keys = %w[2024-04 2024-07 2024-10 2025-01]
    assert_equal expected_keys, result.keys

    # Verify amounts are correct (price 100, evenly split)
    assert_equal 25.0, result["2024-04"]
    assert_equal 25.0, result["2024-07"]
    assert_equal 25.0, result["2024-10"]
    assert_equal 25.0, result["2025-01"]
    assert_sum_equals_missing membership, result
  end

  test "non-standard fiscal year with partial billing across year boundary" do
    org(fiscal_year_start_month: 4) # Fiscal year: April 2024 → March 2025
    travel_to "2024-04-01"
    member = members(:mary)
    member.update!(state: :active)
    membership = create_membership(
      member: member,
      started_on: Date.new(2024, 4, 1),
      ended_on: Date.new(2025, 3, 31),
      billing_year_division: 4
    )
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)

    travel_to "2024-10-01"
    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Q1 and Q2 billed, only Q3 (Oct-Dec) and Q4 (Jan-Mar) remain
    assert_equal 2, result.size
    assert_includes result.keys, "2024-10"
    assert_includes result.keys, "2025-01"
    assert_sum_equals_missing membership, result
  end

  test "jane quarterly billing amounts match invoicer fractions" do
    travel_to "2024-01-01"
    member = members(:jane)
    membership = member.current_membership
    assert_equal 4, membership.billing_year_division
    assert_equal 380, membership.price

    result = Billing::PrevisionalInvoicing.new(membership).compute

    # 380 / 4 = 95.0 per quarter
    assert_equal 95.0, result["2024-01"]
    assert_equal 95.0, result["2024-04"]
    assert_equal 95.0, result["2024-07"]
    assert_equal 95.0, result["2024-10"]
    assert_sum_equals_missing membership, result
  end

  test "jane after Q1 and Q2 invoices" do
    travel_to "2024-01-01"
    member = members(:jane)
    membership = member.current_membership
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal 2, result.size
    assert_includes result.keys, "2024-07"
    assert_includes result.keys, "2024-10"
    assert_sum_equals_missing membership, result
  end

  test "quarterly billing with price change after Q1 invoice" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    # Price change: add depot price
    travel_to "2024-04-01"
    membership.reload
    membership.update!(baskets_annual_price_change: 40) # price increases

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # Q1 was billed at old price, remaining 3 quarters need to cover the difference
    assert_equal 3, result.size
    assert_sum_equals_missing membership, result
  end

  test "triannual billing with decimal amounts rounds to five cents" do
    org(billing_year_divisions: [ 1, 2, 3, 4, 12 ])
    travel_to "2024-01-01"
    membership = memberships(:john) # price 200
    membership.update!(billing_year_division: 3)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # 200 / 3 = 66.666... → round_to_five_cents → 66.65
    # Remaining: 200 - 66.65 = 133.35
    # 133.35 / 2 = 66.675 → round_to_five_cents → 66.70
    # Last period absorbs remainder: 133.35 - 66.70 = 66.65
    assert_equal 3, result.size
    expected_keys = %w[2024-01 2024-05 2024-09]
    assert_equal expected_keys, result.keys

    assert_equal 66.65, result["2024-01"]
    assert_equal 66.7, result["2024-05"]
    assert_equal 66.65, result["2024-09"]

    # All amounts must be multiples of 0.05 (five cents)
    result.each_value do |amount|
      assert_equal 0, (amount * 100).round % 5,
        "Amount #{amount} is not a multiple of 0.05"
    end
    assert_sum_equals_missing membership, result
  end

  test "quarterly billing with uneven decimal price rounds each period to five cents" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    # baskets_annual_price_change of 3 makes price = 203
    membership.update!(baskets_annual_price_change: 3)
    membership.update!(billing_year_division: 4)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    # 203 / 4 = 50.75 → round_to_five_cents → 50.75
    # Remaining: 203 - 50.75 = 152.25
    # 152.25 / 3 = 50.75 → 50.75
    # Remaining: 152.25 - 50.75 = 101.50
    # 101.50 / 2 = 50.75 → 50.75
    # Last: 101.50 - 50.75 = 50.75
    assert_equal 4, result.size

    result.each_value do |amount|
      assert_equal 0, (amount * 100).round % 5,
        "Amount #{amount} is not a multiple of 0.05"
    end
    assert_sum_equals_missing membership, result
  end

  test "monthly billing with small uneven price rounds correctly" do
    org(billing_year_divisions: [ 1, 2, 3, 4, 12 ])
    travel_to "2024-01-01"
    membership = memberships(:john)
    # baskets_annual_price_change of -193 makes price = 7
    membership.update!(baskets_annual_price_change: -193)
    membership.update!(billing_year_division: 12)

    result = Billing::PrevisionalInvoicing.new(membership.reload).compute

    assert_equal 12, result.size

    # Each amount must be a multiple of 0.05
    result.each_value do |amount|
      assert_equal 0, (amount * 100).round % 5,
        "Amount #{amount} is not a multiple of 0.05"
    end
    assert_sum_equals_missing membership, result
  end

  test ".month_label returns localized month and year" do
    assert_equal "January 2024", Billing::PrevisionalInvoicing.month_label("2024-01")
    assert_equal "December 2026", Billing::PrevisionalInvoicing.month_label("2026-12")
  end

  test ".aggregate sums amounts by month across memberships sorted by key" do
    travel_to "2024-01-01"
    m1 = memberships(:john)
    m2 = memberships(:jane)

    m1.update_column(:previsional_invoicing_amounts, { "2024-04" => 100.0, "2024-07" => 50.0 })
    m2.update_column(:previsional_invoicing_amounts, { "2024-01" => 30.0, "2024-04" => 70.0 })

    result = Billing::PrevisionalInvoicing.aggregate([ m1, m2 ])

    assert_equal({ "2024-01" => 30.0, "2024-04" => 170.0, "2024-07" => 50.0 }, result)
  end

  test ".aggregate returns empty hash when no memberships have amounts" do
    travel_to "2024-01-01"
    m1 = memberships(:john)
    m1.update_column(:previsional_invoicing_amounts, {})

    result = Billing::PrevisionalInvoicing.aggregate([ m1 ])

    assert_empty(result)
  end

  private

  def assert_sum_equals_missing(membership, result)
    assert_in_delta membership.missing_invoices_amount.to_f, result.values.sum, 0.01,
      "Sum of previsional amounts should equal missing_invoices_amount"
  end
end

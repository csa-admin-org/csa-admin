# frozen_string_literal: true

require "test_helper"

class Billing::InvoicerTest < ActiveSupport::TestCase
  test "does not create an invoice for inactive member (non-support)" do
    member = members(:mary)
    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "does not create an invoice for member with future membership" do
    travel_to "2023-01-01"
    member = members(:jane)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for not already billed support member" do
    travel_to "2025-01-01"
    member = members(:martha)
    invoice = force_invoice(member)

    assert_nil invoice.entity
    assert_equal "AnnualFee", invoice.entity_type
    assert invoice.annual_fee.present?
    assert_nil invoice.memberships_amount
    assert_equal invoice.annual_fee, invoice.amount
  end

  test "does not create an invoice for already billed support member" do
    travel_to "2025-01-01"
    member = members(:martha)
    create_annual_fee_invoice(member: member)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for trial membership when forced" do
    travel_to "2024-01-01"
    member = members(:jane)
    membership = memberships(:jane)
    membership.update!(billing_year_division: 1)

    assert memberships(:jane).trial?
    assert_difference "Invoice.count", 1 do
      force_invoice(member)
    end
  end

  test "does not bill annual fee for canceled trial membership" do
    travel_to "2024-01-01"
    member = members(:anna)

    assert memberships(:anna).trial?
    invoice = force_invoice(member)

    assert_equal member.memberships.last, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal member.memberships.last.price, invoice.memberships_amount
  end

  test "does not bill annual fee when member annual_fee is nil" do
    travel_to "2025-01-01"
    member = members(:martha)
    member.update_column(:annual_fee, nil)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "does not bill annual fee when member annual_fee is zero" do
    travel_to "2025-01-01"
    member = members(:martha)
    member.update_column(:annual_fee, 0)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for already billed support member (last year)" do
    travel_to "2025-01-01"
    member = members(:martha)
    create_annual_fee_invoice(member: member, date: 1.year.ago)

    invoice = force_invoice(member)

    assert_nil invoice.entity
    assert invoice.annual_fee.present?
    assert_nil invoice.memberships_amount
    assert_equal invoice.annual_fee, invoice.amount
  end

  test "creates an invoice for active member billed yearly" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert invoice.annual_fee.present?
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal 200, invoice.remaining_memberships_amount
    assert_equal "Annual amount", invoice.memberships_amount_description
    assert_equal membership.price, invoice.memberships_amount
  end

  test "does not create an invoice for already billed active member" do
    travel_to "2024-01-01"
    member = members(:john)
    force_invoice(member)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member with future membership" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update_column(:started_on, "2024-02-01")

    assert_difference "Invoice.count", 1 do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member with membership change" do
    travel_to "2024-01-01"
    member = members(:john)
    force_invoice(member)

    member.current_membership.update!(depot_price: 2)

    travel_to "2024-01-02"
    invoice = force_invoice(member)

    assert_equal member.current_membership, invoice.entity
    assert_equal 10, invoice.entity.baskets_count
    assert_nil invoice.annual_fee
    assert_equal 200, invoice.paid_memberships_amount
    assert invoice.memberships_amount_description.present?
    assert_equal 10 * 2, invoice.memberships_amount
  end

  test "creates an invoice for active member with overcharged membership change" do
    travel_to "2024-01-01"
    member = members(:john)
    overcharged_invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs

    member.current_membership.update!(basket_size_price: 19)

    travel_to "2024-01-02"
    invoice = force_invoice(member)

    assert_equal member.current_membership, invoice.entity
    assert_equal 10, invoice.entity.baskets_count
    assert_equal 30, invoice.annual_fee
    assert_equal 0, invoice.paid_memberships_amount
    assert invoice.memberships_amount_description.present?
    assert_equal 10 * 19, invoice.memberships_amount
    assert_equal "canceled", overcharged_invoice.reload.state
  end

  test "creates an invoice for active member billed quarterly" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert invoice.annual_fee.present?
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal membership.price, invoice.remaining_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #1", invoice.memberships_amount_description
  end

  test "does not create an invoice for already billed active member billed quarterly" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update!(billing_year_division: 4)
    force_invoice(member)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member billed quarterly for quarter #2" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal membership.price / 4.0, invoice.paid_memberships_amount
    assert_equal membership.price - membership.price / 4.0, invoice.remaining_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #2", invoice.memberships_amount_description
  end

  test "does not create an invoice for already billed active member billed quarterly for quarter #2" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member billed quarterly for quarter #2 with canceled invoice" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    canceled_invoice = force_invoice(member, send_email: true)
    perform_enqueued_jobs
    canceled_invoice.reload.cancel!
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal membership.price / 4.0, invoice.paid_memberships_amount
    assert_equal membership.price - membership.price / 4.0, invoice.remaining_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #2", invoice.memberships_amount_description
  end

  test "creates an invoice for active member billed quarterly for quarter #3" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal membership.price / 2.0, invoice.paid_memberships_amount
    assert_equal membership.price - membership.price / 2.0, invoice.remaining_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #3", invoice.memberships_amount_description
  end

  test "creates an invoice for active member billed quarterly for quarter #3 with overpaid previous invoices" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    first_invoice = force_invoice(member)

    travel_to "2024-04-01"
    second_invoice = force_invoice(member)

    travel_to "2024-07-01"
    memberships_amount = membership.price / 4.0
    annual_fee = 30

    create_payment(amount: memberships_amount + annual_fee + 1)
    create_payment(amount: memberships_amount + 5)

    assert_equal 0, first_invoice.reload.overpaid
    assert_equal 6, second_invoice.reload.overpaid
    invoice = force_invoice(member)
    perform_enqueued_jobs

    assert_equal membership.price / 2.0, invoice.paid_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #3", invoice.memberships_amount_description

    invoice.reload
    assert_equal 0, first_invoice.reload.overpaid
    assert_equal 0, second_invoice.reload.overpaid
    assert_equal invoice.amount - 6, invoice.missing_amount
  end

  test "does not create an invoice for already billed active member billed quarterly for quarter #3" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)

    assert_not Billing::Invoicer.new(member.reload).billable?
    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "does not create an invoice for already billed active member billed quarterly for quarter #3 with membership change" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)
    member.current_membership.update!(depot_price: 2)

    assert_not Billing::Invoicer.new(member.reload).billable?
    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member billed quarterly for quarter #4" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)

    travel_to "2024-10-01"
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal membership.price * 3 / 4.0, invoice.paid_memberships_amount
    assert_equal membership.price - membership.price * 3 / 4.0, invoice.remaining_memberships_amount
    assert_equal membership.price / 4.0, invoice.memberships_amount
    assert_equal "Quarterly amount #4", invoice.memberships_amount_description
  end

  test "does not create an invoice for already billed active member billed quarterly for quarter #4" do
    travel_to "2024-01-01"
    member = members(:john)
    member.current_membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)

    travel_to "2024-10-01"
    force_invoice(member)

    assert_not Billing::Invoicer.new(member.reload).billable?
    assert_no_difference "Invoice.count" do
      force_invoice(member)
    end
  end

  test "creates an invoice for active member billed quarterly for quarter #4 with membership change" do
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)

    travel_to "2024-10-01"
    force_invoice(member)

    membership.baskets.last.update!(depot_price: 2)
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal 200, invoice.paid_memberships_amount
    assert_equal 1 * 2, invoice.remaining_memberships_amount
    assert_equal 1 * 2, invoice.memberships_amount
    assert_equal "Quarterly amount #4", invoice.memberships_amount_description
  end

  test "does not create an invoice for active member billed quarterly for quarter #4 without deliveries" do
    org(billing_ends_on_last_delivery_fy_month: true)
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership
    membership.update!(billing_year_division: 4)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-07-01"
    force_invoice(member)
    assert_equal 0, member.current_membership.missing_invoices_amount
  end

  test "when billed monthly, month #1" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ])
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert invoice.annual_fee.present?
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal membership.price, invoice.remaining_memberships_amount
    assert_equal 31.65, invoice.memberships_amount
    assert_equal "Monthly amount #1", invoice.memberships_amount_description
  end

  test "when billed monthly, month #4" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ])
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    force_invoice(member)
    travel_to "2024-02-01"
    force_invoice(member)
    travel_to "2024-03-01"
    force_invoice(member)

    travel_to "2024-04-01"
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal 94.95, invoice.paid_memberships_amount
    assert_equal membership.price - 94.95, invoice.remaining_memberships_amount
    assert_equal 31.65, invoice.memberships_amount
    assert_equal "Monthly amount #4", invoice.memberships_amount_description
  end

  test "when billed monthly, month #4 but membership ends at the end of the month" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ])
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    force_invoice(member)
    travel_to "2024-02-01"
    force_invoice(member)
    travel_to "2024-03-01"
    force_invoice(member)

    travel_to "2024-04-01"
    membership.update!(ended_on: "2024-04-30")
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal 94.95, invoice.paid_memberships_amount
    assert_equal 57.05, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.remaining_memberships_amount
    assert_equal "Monthly amount #4", invoice.memberships_amount_description
  end

  test "when billed monthly, month #4 but membership ends in 2 months" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ])
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    force_invoice(member)
    travel_to "2024-02-01"
    force_invoice(member)
    travel_to "2024-03-01"
    force_invoice(member)

    travel_to "2024-04-01"
    membership.update!(ended_on: "2024-05-31")
    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal 94.95, invoice.paid_memberships_amount
    assert_equal 247.05, invoice.remaining_memberships_amount
    assert_equal 123.55, invoice.memberships_amount
    assert_equal "Monthly amount #4", invoice.memberships_amount_description
  end

  test "when billed monthly, month #12" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ])
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    travel_to "2024-02-01"
    force_invoice(member)

    travel_to "2024-12-01"

    invoice = force_invoice(member)

    assert_equal membership, invoice.entity
    assert_nil invoice.annual_fee
    assert_equal 63.30, invoice.paid_memberships_amount
    assert_equal 316.70, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.remaining_memberships_amount
    assert_equal "Monthly amount #12", invoice.memberships_amount_description
  end

  test "when billed monthly, month #5 but membership ended last month" do
    travel_to "2024-01-01"
    org(billing_year_divisions: [ 12 ], trial_baskets_count: 0)
    member = members(:jane)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)
    force_invoice(member)

    travel_to "2024-04-01"
    force_invoice(member)

    travel_to "2024-05-01"
    membership.update!(ended_on: "2024-04-30")

    assert_difference "Invoice.count", 1 do
      force_invoice(member)
    end
    assert_not Billing::Invoicer.new(member.reload).billable?
  end

  test "when billed monthly, month #7 does not include any delivery and billing_ends_on_last_delivery_fy_month is true" do
    travel_to "2024-01-01"
    org(billing_ends_on_last_delivery_fy_month: true)
    member = members(:jane)
    membership = member.current_membership
    membership.update!(billing_year_division: 12)

    travel_to "2024-06-01"
    force_invoice(member)
    assert_equal 0, membership.reload.missing_invoices_amount
  end

  test "future billing" do
    travel_to "2023-12-01"
    membership = memberships(:jane)

    assert membership.started_on > Current.fy_range.min
    assert membership.billable?
    assert membership.price.positive?

    invoicer = Billing::Invoicer.new(membership.member,
      membership: membership,
      period_date: membership.started_on,
      billing_year_division: 1)

    assert invoicer.next_date >= membership.started_on
    assert invoicer.billable?

    invoice = invoicer.invoice
    assert_equal Date.current, invoice.date
    assert_equal membership, invoice.entity
    assert_equal 30, invoice.annual_fee
    assert_equal membership.price, invoice.memberships_amount
    assert_equal 1, invoice.membership_amount_fraction

    membership.reload
    assert_equal 0, membership.missing_invoices_amount
    assert_not membership.billable?

    invoicer = Billing::Invoicer.new(membership.member,
      membership: membership,
      period_date: membership.started_on,
      billing_year_division: 1)
    assert_not invoicer.billable?
  end

  test "next_date for pending member" do
    member = members(:aria)
    assert_nil Billing::Invoicer.new(member).next_date
  end

  test "next_date for waiting member" do
    member = members(:aria)
    assert_nil Billing::Invoicer.new(member).next_date
  end

  test "next_date for inactive member" do
    member = members(:mary)
    assert_nil Billing::Invoicer.new(member).next_date
  end

  test "next_date for support_annual_fee member" do
    member = members(:martha)
    travel_to "2025-01-01"
    assert_equal "2025-01-06", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2025-01-07"
    assert_equal "2025-01-13", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for support_annual_fee member already invoiced" do
    member = members(:martha)
    travel_to "2025-01-01"
    create_annual_fee_invoice(member: member)
    assert_equal "2026-01-05", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date for support_annual_fee member with no annual fee" do
    org(annual_fee: nil, share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(annual_fee: nil, desired_shares_number: 1)
    travel_to "2021-01-01"
    assert_nil Billing::Invoicer.new(member.reload).next_date
  end

  test "next_date for membership beginning of the year, wait after first delivery" do
    org(billing_starts_after_first_delivery: true)
    travel_to "2024-01-01"
    member = members(:john)

    travel_to "2024-01-01"
    assert_equal "2024-04-01", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2024-04-01"
    assert_equal "2024-04-01", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2024-04-02"
    assert_equal "2024-04-08", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for membership beginning of the year with billing_starts_after_first_delivery false" do
    org(billing_starts_after_first_delivery: false)
    travel_to "2024-01-01"
    member = members(:john)

    travel_to "2024-01-01"
    assert_equal "2024-01-01", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2024-01-02"
    assert_equal "2024-01-08", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2024-04-01"
    assert_equal "2024-04-01", Billing::Invoicer.new(member).next_date.to_s
    travel_to "2024-04-02"
    assert_equal "2024-04-08", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for membership just before end of year" do
    travel_to "2024-01-01"
    member = members(:john)

    travel_to "2024-12-31"
    assert_equal "2024-12-31", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for membership already invoiced (billing_year_division 1)" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.current_membership.update!(billing_year_division: 1)

    travel_to "2024-04-15"
    assert_equal "2024-04-15", Billing::Invoicer.new(member).next_date.to_s
    force_invoice(member)

    assert_nil Billing::Invoicer.new(member.reload).next_date
    travel_to "2024-12-01"
    assert_nil Billing::Invoicer.new(member.reload).next_date
  end

  test "next_date for membership already invoiced (billing_year_division 4)" do
    travel_to "2024-01-01"
    member = members(:jane)

    travel_to "2024-04-01"
    assert_equal "2024-04-01", Billing::Invoicer.new(member).next_date.to_s
    force_invoice(member)

    assert_equal "2024-07-01", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-08-01"
    assert_equal "2024-08-05", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-10-01"
    assert_equal "2024-10-07", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-12-31"
    assert_equal "2024-12-31", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for membership already invoiced (billing_year_division 12)" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.current_membership.update!(billing_year_division: 12)

    travel_to "2024-04-01"
    assert_equal "2024-04-15", Billing::Invoicer.new(member).next_date.to_s
    force_invoice(member)

    assert_equal "2024-05-06", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-08-01"
    assert_equal "2024-08-05", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-10-01"
    assert_equal "2024-10-07", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-12-31"
    assert_equal "2024-12-31", Billing::Invoicer.new(member).next_date.to_s
  end

  test "next_date for future membership, current year" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 0)
    member = members(:jane)
    membership = memberships(:jane)
    membership.update!(
      billing_year_division: 12,
      started_on: "2024-04-01",
      new_config_from: "2024-04-01")

    assert_equal "2024-04-04", membership.deliveries.first.date.to_s
    assert_equal "2024-04-01", Billing::Invoicer.new(member.reload).next_date.to_s

    travel_to "2024-11-01"
    assert_equal "2024-11-04", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date for future membership, next year" do
    travel_to "2023-07-01"
    org(trial_baskets_count: 0)
    member = members(:jane)
    membership = memberships(:jane)

    assert_equal "2024-04-04", membership.deliveries.first.date.to_s
    assert_equal "2024-01-01", Billing::Invoicer.new(member.reload).next_date.to_s

    Billing::InvoicerFuture.invoice(membership)
    assert_nil Billing::Invoicer.new(member.reload).next_date

    perform_enqueued_jobs do
      Delivery.create! date: membership.deliveries.last.date + 1.week
    end
    assert_equal "2024-01-01", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date for past membership, last year" do
    travel_to "2023-01-01"
    org(trial_baskets_count: 0)
    member = members(:jane)
    membership = memberships(:jane)

    assert_equal "2024-04-04", membership.deliveries.first.date.to_s

    travel_to "2024-12-31"
    assert_equal "2024-12-31", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2025-01-01"
    assert_nil Billing::Invoicer.new(member.reload).next_date
  end

  test "next_date with trial baskets" do
    travel_to "2024-01-01"
    org(trial_baskets_count: 2)
    member = members(:jane)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert_equal "2024-04-04", membership.deliveries.first.date.to_s
    assert_equal "2024-04-11", membership.baskets.trial.last.delivery.date.to_s

    travel_to "2024-04-04"
    assert_equal "2024-04-15", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-04-16"
    assert_equal "2024-04-22", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-11-02"
    assert_equal "2024-11-04", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date with trial baskets, three trial baskets" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 11)
    membership = memberships(:jane)
    membership.update_baskets_counts!

    assert_equal 10, membership.deliveries.count
    assert_equal "2024-04-04", membership.deliveries.first.date.to_s
    assert_equal "2024-06-06", membership.deliveries.last.date.to_s

    travel_to "2024-04-04"
    assert_equal "2024-06-10", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-06-10"
    assert_equal "2024-06-10", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-12-31"
    assert_equal "2024-12-31", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date with custom deliveries cycle" do
    travel_to "2024-01-01"
    member = members(:jane)
    member.update!(trial_baskets_count: 0)
    membership = memberships(:jane)
    membership.update!(billing_year_division: 12)
    cycle = delivery_cycles(:thursdays)
    cycle.update!(
      periods_attributes: cycle.periods.map { |p| { id: p.id, _destroy: true } } + [
        { from_fy_month: 5, to_fy_month: 5, results: :all }
      ]
    )
    perform_enqueued_jobs

    assert_equal 5, membership.deliveries.count
    assert_equal "2024-05-02", membership.deliveries.first.date.to_s
    assert_equal "2024-05-30", membership.deliveries.last.date.to_s

    travel_to "2024-01-01"
    assert_equal "2024-01-01", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-05-01"
    assert_equal "2024-05-06", Billing::Invoicer.new(member.reload).next_date.to_s
    travel_to "2024-07-01"
    assert_equal "2024-07-01", Billing::Invoicer.new(member.reload).next_date.to_s
  end

  test "next_date returns nil when billing_starts_after_first_delivery and no billable delivery exists" do
    org(billing_starts_after_first_delivery: true)
    travel_to "2024-01-01"
    member = members(:john)
    membership = member.current_membership

    # Set all basket quantities to 0 so there's no filled billable delivery
    membership.baskets.update_all(quantity: 0)

    assert_nil membership.first_billable_delivery
    assert_nil Billing::Invoicer.new(member.reload).next_date
  end
end

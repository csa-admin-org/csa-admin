# frozen_string_literal: true

require "test_helper"

class Analytics::BillingTest < ActiveSupport::TestCase
  setup do
    travel_to "2025-01-15"
  end

  test "sums paid payments for the fiscal year" do
    year = Analytics::Billing.new.for(2024)

    assert_equal 10.to_d, year.paid_amount
    assert Analytics::Billing.new.payments?
  end

  test "omits unused memberships and annual fees from invoice amount stacks" do
    year = Data.define(:memberships_amount, :annual_fee_amount, :amounts_by_type).new(
      0, 0, { "Other" => 10.to_d })
    billing = Analytics::Billing.new

    billing.stub(:series, [ year ]) do
      labels = billing.send(:invoice_amount_datasets).map(&:first)

      assert_equal [ I18n.t("billing.other") ], labels
    end
  end

  test "keeps memberships and annual fees in invoice amount stacks when used" do
    labels = Analytics::Billing.new.send(:invoice_amount_datasets).map(&:first)

    assert_includes labels, Membership.model_name.human(count: 2)
    assert_includes labels, I18n.t("billing.annual_fees")
    assert_includes labels, I18n.t("billing.other")
  end

  test "sums membership amount, annual fee column, and other types" do
    year = Analytics::Billing.new.for(2024)

    assert_equal 3, year.count
    assert_equal 19, year.memberships_amount
    assert_equal 30, year.annual_fee_amount
    assert_equal 10, year.amounts_by_type["Other"]
    assert_equal 59, year.amount
  end

  test "excludes canceled invoices" do
    invoices(:annual_fee).cancel!
    year = Analytics::Billing.new.for(2024)

    assert_equal 2, year.count
    assert_equal 0, year.annual_fee_amount
    assert_equal 29, year.amount
  end

  test "computes median and p90 time to pay from first non-ignored payment" do
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2024, 5, 1),
      sent_at: Time.zone.parse("2024-05-01 09:00"),
      amount: 60)
    create_payment(member: members(:jane), invoice: invoice, amount: 50, date: Date.new(2024, 5, 11))
    create_payment(member: members(:jane), invoice: invoice, amount: 10, date: Date.new(2024, 5, 21))

    year = Analytics::Billing.new.for(2024)

    assert_equal 2, year.time_to_pay_count
    assert_equal 5.5, year.time_to_pay_median
    assert_in_delta 9.1, year.time_to_pay_p90, 0.01
  end

  test "uses the local date of sent_at for time to pay" do
    # 00:30 local is the previous day in UTC; SQLite date() on the raw
    # UTC value would count one day too many.
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2024, 5, 1),
      sent_at: Time.zone.parse("2024-05-01 00:30"),
      amount: 60)
    create_payment(member: members(:jane), invoice: invoice, amount: 60, date: Date.new(2024, 5, 11))

    year = Analytics::Billing.new.for(2024)

    assert_equal 2, year.time_to_pay_count
    assert_equal 5.5, year.time_to_pay_median
  end

  test "clamps negative time to pay to zero" do
    invoice = invoices(:other_closed)
    invoice.update_column(:sent_at, Time.zone.parse("2024-04-10 09:00"))
    year = Analytics::Billing.new.for(2024)

    assert_equal 1, year.time_to_pay_count
    assert_equal 0, year.time_to_pay_median
    assert_equal 0, year.time_to_pay_p90
  end

  test "ignores ignored payments and unpaid invoices for time to pay" do
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2024, 6, 1))
    create_payment(
      member: members(:jane),
      invoice: invoice,
      amount: 20,
      date: Date.new(2024, 6, 5),
      ignored_at: Time.current)
    create_other_invoice(
      member: members(:anna),
      date: Date.new(2024, 6, 2))

    year = Analytics::Billing.new.for(2024)

    assert_equal 1, year.time_to_pay_count
    assert_equal 1, year.time_to_pay_median
  end

  test "excludes zero-amount invoices from time to pay" do
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2024, 7, 1),
      amount: 0)
    create_payment(
      member: members(:jane),
      invoice: invoice,
      amount: 5,
      date: Date.new(2024, 7, 3))

    year = Analytics::Billing.new.for(2024)

    assert_equal 1, year.time_to_pay_count
    assert_equal 1, year.time_to_pay_median
  end

  test "computes YTD time to pay for an in-progress year" do
    invoice = create_other_invoice(
      member: members(:jane),
      date: Date.new(2025, 1, 2),
      sent_at: Time.zone.parse("2025-01-02 09:00"),
      amount: 40)
    create_payment(
      member: members(:jane),
      invoice: invoice,
      amount: 40,
      date: Date.new(2025, 1, 10))

    year = Analytics::Billing.new.for(2025)

    assert year.in_progress?
    assert_equal 1, year.time_to_pay_count
    assert_equal 8, year.time_to_pay_median
    assert_equal 8, year.time_to_pay_p90
  end
end

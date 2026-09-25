# frozen_string_literal: true

require "test_helper"

class Shop::InvoicePeriodTest < ActiveSupport::TestCase
  test "calendar keys and the morning after the period ends" do
    monday = Date.new(2026, 9, 21) # Q3

    assert_equal "2026-09", Shop::InvoicePeriod.key_for("month", monday)
    assert_equal Date.new(2026, 10, 1), Shop::InvoicePeriod.billing_on("month", monday)
    assert_equal "2026-Q3", Shop::InvoicePeriod.key_for("quarter", monday)
    assert_equal Date.new(2026, 10, 1), Shop::InvoicePeriod.billing_on("quarter", monday)
    assert_equal "2026", Shop::InvoicePeriod.key_for("year", monday)
    assert_equal Date.new(2027, 1, 1), Shop::InvoicePeriod.billing_on("year", monday)
  end

  test "a blank member period means each order" do
    member = members(:jane)
    member.update!(shop_invoice_period: "")

    assert member.valid?
    assert_nil member.shop_invoice_period

    member.update!(shop_invoice_period: "month")
    member.shop_invoice_period = ""
    assert member.valid?
    assert_nil member.shop_invoice_period
  end

  test "a blank organization period is nil and members follow it unless they override" do
    Current.org.update!(shop_invoice_period: "")
    assert_nil Current.org.shop_invoice_period

    member = members(:jane)
    member.update!(shop_invoice_period: nil)
    assert_nil member.effective_shop_invoice_period

    Current.org.update!(shop_invoice_period: "year")
    assert_equal "year", member.effective_shop_invoice_period

    member.update!(shop_invoice_period: "month")
    assert_equal "month", member.effective_shop_invoice_period

    Current.org.shop_invoice_period = "week"
    assert_not Current.org.valid?
  end

  test "due on the billing morning, not the day before" do
    date = Date.new(2026, 9, 21)

    assert_not Shop::InvoicePeriod.due?("month", date, on: Date.new(2026, 9, 30))
    assert Shop::InvoicePeriod.due?("month", date, on: Date.new(2026, 10, 1))
  end
end

# frozen_string_literal: true

require "test_helper"

class Billing::ShopOrderGroupInvoicerJobTest < ActiveJob::TestCase
  test "skips period members in the per-order path and bills a closed period" do
    travel_to "2024-05-01"
    org(shop_order_automatic_invoicing_delay_in_days: 0)
    members(:jane).update!(shop_invoice_period: "month")
    grouped = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))
    single = create_shop_order(member: members(:john), delivery: deliveries(:thursday_1))

    assert_no_changes -> { grouped.reload.state } do
      grouped.auto_invoice!
    end
    assert_not_includes Shop::Order.pending.without_invoice_period, grouped
    assert_includes Shop::Order.pending.without_invoice_period, single

    perform_enqueued_jobs only: Billing::ShopOrderGroupInvoicerJob do
      Billing::ShopOrderGroupInvoicerJob.perform_later
    end
    single.auto_invoice!

    assert grouped.reload.invoiced?
    assert_equal "Shop::OrderGroup", grouped.invoice.entity_type
    assert single.reload.invoiced?
    assert_equal "Shop::Order", single.invoice.entity_type
  end

  test "bills a closed period even when per-order delay is blank" do
    travel_to "2024-05-01"
    org(shop_order_automatic_invoicing_delay_in_days: nil)
    members(:jane).update!(shop_invoice_period: "month")
    order = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))

    perform_enqueued_jobs only: Billing::ShopOrderGroupInvoicerJob do
      Billing::ShopOrderGroupInvoicerJob.perform_later
    end

    assert order.reload.invoiced?
    assert_equal "Shop::OrderGroup", order.invoice.entity_type
  end

  test "an organization period groups members with no override and skips per-order invoicing" do
    travel_to "2024-05-01"
    org(shop_invoice_period: "month", shop_order_automatic_invoicing_delay_in_days: 0)
    order = create_shop_order(member: members(:john), delivery: deliveries(:thursday_1))

    assert order.group_invoice?
    assert_not_includes Shop::Order.pending.without_invoice_period, order
    assert_includes Shop::Order.pending.with_invoice_period, order

    assert_no_enqueued_jobs only: Billing::ShopOrderAutoInvoicerJob do
      Scheduled::BillingShopOrdersAutoInvoicerJob.perform_now
    end

    perform_enqueued_jobs only: Billing::ShopOrderGroupInvoicerJob do
      Billing::ShopOrderGroupInvoicerJob.perform_later
    end

    assert order.reload.invoiced?
    assert_equal "Shop::OrderGroup", order.invoice.entity_type
  end

  test "a member period overrides the organization period" do
    travel_to "2024-05-01"
    org(shop_invoice_period: "month")
    members(:jane).update!(shop_invoice_period: "quarter")
    order = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))

    assert_equal "2024-Q2", order.invoice_period_key
    assert_not order.group_invoice_due?

    perform_enqueued_jobs only: Billing::ShopOrderGroupInvoicerJob do
      Billing::ShopOrderGroupInvoicerJob.perform_later
    end

    assert order.reload.pending?
  end

  test "does nothing without an IBAN" do
    travel_to "2024-05-01"
    org(iban: nil)
    members(:jane).update!(shop_invoice_period: "month")
    order = create_shop_order(member: members(:jane), delivery: deliveries(:monday_1))

    assert_no_difference -> { Invoice.count } do
      perform_enqueued_jobs only: Billing::ShopOrderGroupInvoicerJob do
        Billing::ShopOrderGroupInvoicerJob.perform_later
      end
    end
    assert order.reload.pending?
  end
end

# frozen_string_literal: true

require "test_helper"

class InvoiceEntityTypeTest < ActiveSupport::TestCase
  test "the shop order filter includes groups without adding a second object type" do
    travel_to "2024-04-10"
    members(:jane).update!(shop_invoice_period: "month")
    order = create_shop_order(delivery: deliveries(:monday_1))
    invoice = Shop::OrderGroup.invoice_orders!([ order ], send_email: false).invoice

    assert_not order.can_invoice?
    assert_includes Invoice.entity_type_eq("Shop::Order"), invoice
    assert_not_includes Invoice.used_entity_types, "Shop::OrderGroup"
    assert_includes Invoice.used_entity_types, "Shop::Order"
    assert invoice.shop_order_type?
    assert_equal Current.org.vat_shop_rate, invoice.vat_rate if Current.org.feature?("vat")
  end
end

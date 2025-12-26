# frozen_string_literal: true

require "test_helper"

class Invoice::AmountsTest < ActiveSupport::TestCase
  test "raises on amount=" do
    assert_raises(NoMethodError) { Invoice.new(amount: 1) }
  end

  test "raises on balance=" do
    assert_raises(NoMethodError) { Invoice.new(balance: 1) }
  end

  test "raises on paid_amount=" do
    assert_raises(NoMethodError) { Invoice.new(paid_amount: 1) }
  end

  test "set percentage (reduction)" do
    invoice = Invoice.new(
      amount_percentage: -10.1,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal(-10.1, invoice.amount_percentage)
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(8.99, 6), invoice.amount
  end

  test "set percentage (increase)" do
    invoice = Invoice.new(
      amount_percentage: 2.51,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 2.51, invoice.amount_percentage
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(10.25, 6), invoice.amount
  end

  test "with vat" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")

    invoice = Invoice.new(
      vat_rate: 2.5,
      amount_percentage: 10,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 10, invoice.amount_percentage
    assert_equal 10, invoice.amount_before_percentage
    assert_equal BigDecimal(11, 6), invoice.amount
    assert_equal 2.5, invoice.vat_rate
    assert_equal 11, invoice.amount_with_vat
    assert_equal BigDecimal(10.73, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.27, 4), invoice.vat_amount
  end

  test "does not set vat for non-membership invoices" do
    invoice = create_annual_fee_invoice
    assert_nil invoice.vat_amount
    assert_nil invoice.vat_rate
  end

  test "does not set vat when the organization has no VAT set" do
    org(vat_membership_rate: nil)

    invoice = create_membership_invoice
    assert_nil invoice.vat_rate
    assert_nil invoice.vat_amount
  end

  test "sets the vat_amount for membership invoice and the organization with rate set" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")
    invoice = create_membership_invoice

    assert_equal 7.7, invoice.vat_rate
    assert_equal 200, invoice.amount_with_vat
    assert_equal BigDecimal(185.7, 6), invoice.amount_without_vat
    assert_equal BigDecimal(14.3, 4), invoice.vat_amount
  end

  test "sets the vat_amount for activity participation invoice" do
    org(vat_activity_rate: 5.5, vat_number: "XXX")
    invoice = Invoice.new(
      missing_activity_participations_count: 2,
      missing_activity_participations_fiscal_year: Current.fiscal_year,
      activity_price: 60)
    invoice.validate

    assert_equal 5.5, invoice.vat_rate
    assert_equal 120, invoice.amount_with_vat
    assert_equal BigDecimal(113.74, 6), invoice.amount_without_vat
    assert_equal BigDecimal(6.26, 4), invoice.vat_amount
  end

  test "sets the vat_amount for shop order invoice" do
    org(vat_shop_rate: 2.5, vat_number: "XXX")
    invoice = shop_orders(:john).invoice!

    assert_equal 2.5, invoice.vat_rate
    assert_equal 5, invoice.amount_with_vat
    assert_equal BigDecimal(4.88, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.12, 4), invoice.vat_amount
  end

  test "accepts custom vat_rate" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")
    invoice = Invoice.new(
      vat_rate: 2.5,
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_equal 2.5, invoice.vat_rate
    assert_equal 10, invoice.amount_with_vat
    assert_equal BigDecimal(9.76, 6), invoice.amount_without_vat
    assert_equal BigDecimal(0.24, 4), invoice.vat_amount
  end

  test "accepts no vat_rate" do
    org(vat_membership_rate: 7.7, vat_number: "XXX")

    invoice = Invoice.new(
      vat_rate: "",
      items_attributes: {
        "0" => { description: "Cool cheap thing", amount: "10" }
      })
    invoice.validate

    assert_nil invoice.vat_rate
    assert_equal 10, invoice.amount_with_vat
    assert_equal 10, invoice.amount_without_vat
    assert_nil invoice.vat_amount
  end

  test "overpaid" do
    invoice = invoices(:annual_fee)
    create_payment(invoice: invoice, amount: 30)

    admin = admins(:ultra)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_changes -> { invoice.reload.overpaid? }, to: true do
      create_payment(invoice: invoice, amount: 100)
    end

    assert_difference "AdminMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.send_overpaid_notification_to_admins! }
    end

    mail = AdminMailer.deliveries.last
    assert_equal "Overpaid invoice ##{invoice.id}", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.body.encoded, "Hello Thibaud,"
    assert_includes mail.body.encoded, "Martha"
  end

  test "does not send notification when not overpaid" do
    invoice = invoices(:annual_fee)

    admin = admins(:ultra)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_no_changes -> { invoice.reload.overpaid_notification_sent_at } do
      invoice.send_overpaid_notification_to_admins!
    end
    assert_equal 0, AdminMailer.deliveries.size
  end

  test "does not send notification when already notified" do
    invoice = invoices(:annual_fee)
    create_payment(invoice: invoice, amount: 30)
    invoice.touch(:overpaid_notification_sent_at)

    admin = admins(:ultra)
    admin.update!(notifications: %w[invoice_overpaid])

    assert_no_difference "AdminMailer.deliveries.size" do
      perform_enqueued_jobs { invoice.send_overpaid_notification_to_admins! }
    end
  end
end

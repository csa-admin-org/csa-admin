# frozen_string_literal: true

require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "ensure invoice currency matches" do
    org(
      features: [ "local_currency" ],
      local_currency_code: "RAD",
      local_currency_identifier: "test_shop",
      local_currency_wallet: "0x1234567890abcdef")

    invoice = invoices(:annual_fee)

    payment = Payment.new(
      invoice: invoice,
      amount: 42,
      date: Date.today)

    assert_equal invoice.currency_code, payment.currency_code
    assert payment.valid?

    payment.currency_code = "RAD"

    assert_not payment.valid?
    assert_includes payment.errors[:currency_code], "is invalid"
  end

  test "store created_by via audit" do
    payment = create_payment
    assert_equal System.instance, payment.created_by

    Current.session = sessions(:ultra)
    payment = create_payment
    assert_equal admins(:ultra), payment.created_by
  end

  test "store updated_by" do
    payment = create_payment
    assert_nil payment.updated_by

    payment.update(amount: 1)
    assert_equal System.instance, payment.updated_by

    Current.session = sessions(:ultra)
    payment.update(amount: 2)
    assert_equal admins(:ultra), payment.updated_by
  end

  test "#ignore / #unignore" do
    invoice = invoices(:annual_fee)

    payment = create_payment(
      origin: "camt.054",
      member: invoice.member,
      amount: invoice.amount)

    assert invoice.reload.closed?
    assert_equal 0, invoice.member.balance_amount

    payment.ignore!

    assert_not invoice.reload.closed?
    assert_equal(-30, invoice.member.balance_amount)

    payment.unignore!

    assert invoice.reload.closed?
    assert_equal 0, invoice.member.balance_amount
  end

  test "send reversal notification to admins" do
    invoice = invoices(:annual_fee)

    admin = admins(:ultra)
    admin.update!(notifications: %w[payment_reversal])

    payment = create_payment(
      invoice: invoice,
      member: invoice.member,
      amount: -1 * invoice.amount)

    assert_difference "AdminMailer.deliveries.size" do
      perform_enqueued_jobs { payment.send_reversal_notification_to_admins! }
    end

    mail = AdminMailer.deliveries.last
    assert_equal "Payment reversal for invoice ##{invoice.id}", mail.subject
    assert_equal [ admin.email ], mail.to
    assert_includes mail.body.encoded, "Hello Thibaud,"
    assert_includes mail.body.encoded, "Martha"
  end
end

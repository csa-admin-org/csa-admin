# frozen_string_literal: true

require "test_helper"

class PaymentTest < ActiveSupport::TestCase
  test "store created_by via audit" do
    payment = create_payment
    assert_equal System.instance, payment.created_by

    Current.session = sessions(:master)
    payment = create_payment
    assert_equal admins(:master), payment.created_by
  end

  test "store updated_by" do
    payment = create_payment
    assert_nil payment.updated_by

    payment.update(amount: 1)
    assert_equal System.instance, payment.updated_by

    Current.session = sessions(:master)
    payment.update(amount: 2)
    assert_equal admins(:master), payment.updated_by
  end

  test "#ignore / #unignore" do
    invoice = invoices(:annual_fee)

    payment = create_payment(
      member: invoice.member,
      amount: invoice.amount,
      fingerprint: "foo")

    assert invoice.reload.closed?
    assert_equal 0, invoice.member.balance_amount

    payment.ignore!

    assert_not invoice.reload.closed?
    assert_equal -30, invoice.member.balance_amount

    payment.unignore!

    assert invoice.reload.closed?
    assert_equal 0, invoice.member.balance_amount
  end
end

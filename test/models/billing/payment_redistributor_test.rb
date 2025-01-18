# frozen_string_literal: true

require "test_helper"

class Billing::PaymentsRedistributorTest < ActiveSupport::TestCase
  def redistribute!(member)
    Billing::PaymentsRedistributor.redistribute!(member.id)
  end

  test "splits payments amount on not canceled invoices" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    invoice1 = create_invoice(
      date: "2024-01-01",
      entity: membership,
      memberships_amount_description: "Amount #1",
      membership_amount_fraction: 3)
    invoice2 = create_invoice(
      date: "2024-01-02",
      entity: membership,
      memberships_amount_description: "Amount #2",
      membership_amount_fraction: 2)
    invoice3 = create_invoice(
      state: "canceled",
      date: "2024-01-03",
      entity: membership,
      memberships_amount_description: "Amount #3",
      membership_amount_fraction: 1)
    invoice3_bis = create_invoice(
      date: "2024-01-04",
      entity: membership,
      memberships_amount_description: "Amount #3",
      membership_amount_fraction: 1)

    create_payment(invoice: invoice3, amount: 66.65)
    create_payment(amount: 70)

    redistribute!(members(:john))

    assert_equal 66.65, invoice1.reload.paid_amount
    assert_equal "closed", invoice1.state
    assert_equal 66.70, invoice2.reload.paid_amount
    assert_equal "closed", invoice2.state
    assert_equal 0, invoice3.reload.paid_amount
    assert_equal "canceled", invoice3.state
    assert_equal 3.30, invoice3_bis.reload.paid_amount
    assert_equal "open", invoice3_bis.state
  end

  test "handles payments with invoice_id first" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    invoice1 = create_invoice(
      date: "2024-01-01",
      entity: membership,
      memberships_amount_description: "Amount #1",
      membership_amount_fraction: 3)
    invoice2 = create_invoice(
      date: "2024-01-02",
      entity: membership,
      memberships_amount_description: "Amount #2",
      membership_amount_fraction: 2)
    invoice3 = create_invoice(
      date: "2024-01-03",
      entity: membership,
      memberships_amount_description: "Amount #3",
      membership_amount_fraction: 1)

    create_payment(invoice: invoice1, amount: 66.65)
    create_payment(invoice: invoice3, amount: 60)
    create_payment(invoice: invoice3, amount: 10)
    create_payment(amount: -3)

    redistribute!(members(:john))

    assert_equal 66.65, invoice1.reload.paid_amount
    assert_equal "closed", invoice1.state
    assert_equal 0.35, invoice2.reload.paid_amount
    assert_equal "open", invoice2.state
    assert_equal 66.65, invoice3.reload.paid_amount
    assert_equal "closed", invoice3.state
  end

  test "handles payments with invoice_id first, but remove money from the previously open invoice" do
    travel_to "2024-01-01"
    membership = memberships(:john)
    invoice1 = create_invoice(
      date: "2024-01-01",
      entity: membership,
      memberships_amount_description: "Amount #1",
      membership_amount_fraction: 3)
    invoice2 = create_invoice(
      date: "2024-01-02",
      entity: membership,
      memberships_amount_description: "Amount #2",
      membership_amount_fraction: 2)
    invoice3 = create_invoice(
      date: "2024-01-03",
      entity: membership,
      memberships_amount_description: "Amount #3",
      membership_amount_fraction: 1)

    create_payment(invoice: invoice1, amount: 66.65)
    create_payment(invoice: invoice3, amount: 66.65)
    create_payment(invoice: invoice3, amount: 66.70)
    create_payment(amount: -3)

    redistribute!(members(:john))

    assert_equal 66.65, invoice1.reload.paid_amount
    assert_equal "closed", invoice1.state
    assert_equal 63.70, invoice2.reload.paid_amount
    assert_equal "open", invoice2.state
    assert_equal 66.65, invoice3.reload.paid_amount
    assert_equal "closed", invoice3.state
  end

  test "handles payback invoice with negative amount" do
    travel_to "2024-01-01"
    org(share_price: 30, shares_number: 1)

    membership = memberships(:john)
    invoice1 = create_invoice(
      date: "2024-01-01",
      entity: membership,
      memberships_amount_description: "Amount #1",
      membership_amount_fraction: 3)
    invoice2 = create_invoice(
      date: "2024-01-02",
      shares_number: -2)
    invoice3 = create_invoice(
      date: "2024-01-03",
      entity: membership,
      memberships_amount_description: "Amount #2",
      membership_amount_fraction: 2)

    create_payment(invoice: invoice1, amount: 66.65)

    redistribute!(members(:john))

    assert_equal 66.65, invoice1.reload.paid_amount
    assert_equal "closed", invoice1.state
    assert_equal 0, invoice2.reload.paid_amount
    assert_equal "closed", invoice2.state
    assert_equal 60.00, invoice3.reload.paid_amount
    assert_equal "open", invoice3.state
  end

  test "handles payback invoice with negative amount with direct negative payment" do
    travel_to "2024-01-01"
    org(share_price: 30, shares_number: 1)

    membership = memberships(:john)
    invoice1 = create_invoice(
      date: "2024-01-01",
      entity: membership,
      memberships_amount_description: "Amount #1",
      membership_amount_fraction: 3)
    invoice2 = create_invoice(
      date: "2024-01-02",
      shares_number: -2)
    invoice3 = create_invoice(
      date: "2024-01-03",
      entity: membership,
      memberships_amount_description: "Amount #2",
      membership_amount_fraction: 2)

    create_payment(invoice: invoice1, amount: 66.65)
    create_payment(invoice: invoice2, amount: -60)

    redistribute!(members(:john))

    assert_equal 66.65, invoice1.reload.paid_amount
    assert_equal "closed", invoice1.state
    assert_equal 0, invoice2.reload.paid_amount
    assert_equal "closed", invoice2.state
    assert_equal 0, invoice3.reload.paid_amount
    assert_equal "open", invoice3.state
  end
end

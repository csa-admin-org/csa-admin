# frozen_string_literal: true

require "test_helper"

class Invoice::MembershipBillingTest < ActiveSupport::TestCase
  test "raises on memberships_amount=" do
    assert_raises(NoMethodError) { Invoice.new(memberships_amount: 1) }
  end

  test "raises on remaining_memberships_amount=" do
    assert_raises(NoMethodError) { Invoice.new(remaining_memberships_amount: 1) }
  end

  test "default values for membership" do
    invoice = create_membership_invoice

    assert_nil invoice.annual_fee
    assert_equal "Membership", invoice.entity_type
    assert_equal 200, invoice.memberships_amount
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal 200, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when paid_memberships_amount set" do
    invoice = create_membership_invoice(paid_memberships_amount: 40)

    assert_equal 160, invoice.memberships_amount
    assert_equal 40, invoice.paid_memberships_amount
    assert_equal 160, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when membership_amount_fraction set" do
    invoice = create_membership_invoice(membership_amount_fraction: 4)

    assert_equal 50, invoice.memberships_amount
    assert_equal 0, invoice.paid_memberships_amount
    assert_equal 200, invoice.remaining_memberships_amount
    assert_equal invoice.memberships_amount, invoice.amount
  end

  test "when annual_fee present as well" do
    invoice = create_membership_invoice(annual_fee: 30)

    assert invoice.annual_fee.present?
    assert_equal invoice.memberships_amount + invoice.annual_fee, invoice.amount
  end
end

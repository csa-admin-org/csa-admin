# frozen_string_literal: true

require "test_helper"

class Invoice::SharesBillingTest < ActiveSupport::TestCase
  test "sets entity_type to Share with shares_number" do
    org(share_price: 250, shares_number: 1)
    invoice = Invoice.new(shares_number: -2)

    assert_equal "Share", invoice.entity_type
    assert_equal(-2, invoice.shares_number)
    assert_equal(-500, invoice.amount)
  end

  test "sets entity_type to Share with positive shares_number" do
    org(share_price: 100, shares_number: 1)
    invoice = Invoice.new(shares_number: 3)

    assert_equal "Share", invoice.entity_type
    assert_equal 3, invoice.shares_number
    assert_equal 300, invoice.amount
  end

  test "shares_number does not set when zero" do
    org(share_price: 100, shares_number: 1)
    invoice = Invoice.new(shares_number: 0)

    assert_nil invoice.shares_number
    assert_nil invoice.entity_type
  end

  test "validates shares_number must not be zero" do
    org(share_price: 100, shares_number: 1)
    invoice = Invoice.new
    invoice[:shares_number] = 0
    invoice[:entity_type] = "Share"

    assert_not invoice.valid?
    assert_includes invoice.errors[:shares_number], "must be other than 0"
  end

  test "validates shares_number absence when not share type" do
    invoice = Invoice.new
    invoice[:shares_number] = 1
    invoice[:entity_type] = "Other"

    assert_not invoice.valid?
    assert_includes invoice.errors[:shares_number], "must be blank"
  end

  test "validates items absence when share type" do
    org(share_price: 100, shares_number: 1)
    invoice = Invoice.new(shares_number: 1)
    invoice.items.build(description: "Test", amount: 10)

    assert_not invoice.valid?
    assert_includes invoice.errors[:items], "must be blank"
  end

  test "can_refund? returns true when closed with positive shares" do
    org(share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(existing_shares_number: 2)

    invoice = create_invoice(member: member, shares_number: 1)
    invoice.update!(state: "closed", sent_at: Time.current)

    assert invoice.can_refund?
  end

  test "can_refund? returns false when not closed" do
    org(share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(existing_shares_number: 2)

    invoice = create_invoice(member: member, shares_number: 1)
    invoice.update!(state: "open", sent_at: Time.current)

    assert_not invoice.can_refund?
  end

  test "can_refund? returns false when member has no shares left" do
    org(share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(existing_shares_number: 1)

    # Create a refund invoice (-1 share) - after this, member has 0 shares
    invoice = create_invoice(member: member, shares_number: -1)
    invoice.update!(state: "closed", sent_at: Time.current)

    # Member now has 0 shares (1 existing - 1 from invoice)
    assert_equal 0, member.shares_number
    assert_not invoice.can_refund?
  end

  test "can_refund? returns false when invoice shares_number is negative" do
    org(share_price: 100, shares_number: 1)
    member = members(:martha)
    member.update!(existing_shares_number: 2)

    invoice = create_invoice(member: member, shares_number: -1)
    invoice.update!(state: "closed", sent_at: Time.current)

    assert_not invoice.can_refund?
  end

  test "changes inactive member state to support and back to inactive" do
    org(share_price: 250, shares_number: 1)
    member = members(:mary)

    assert_changes -> { member.reload.state }, from: "inactive", to: "support" do
      create_invoice(member: member, shares_number: 1)
      perform_enqueued_jobs
    end

    assert_changes -> { member.reload.state }, from: "support", to: "inactive" do
      create_invoice(member: member, shares_number: -1)
      perform_enqueued_jobs
    end
  end
end

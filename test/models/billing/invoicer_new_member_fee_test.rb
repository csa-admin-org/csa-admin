# frozen_string_literal: true

require "test_helper"

class Billing::InvoicerNewMemberFeeTest < ActiveSupport::TestCase
  def invoice(member, **attrs)
    Billing::InvoicerNewMemberFee.invoice(member, **attrs)
  end

  test "create invoice for recent new member" do
    travel_to "2023-05-01"
    member = members(:john)

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end

    invoice = member.invoices.last
    assert_equal Date.current, invoice.date
    assert_equal "NewMemberFee", invoice.entity_type
    assert_equal 33, invoice.amount
    assert_equal 1, invoice.items.count
    assert_equal "Empty baskets", invoice.items.first.description
    assert_equal 33, invoice.items.first.amount
  end

  test "do nothing if new_member_fee is not enabled" do
    travel_to "2023-05-01"
    org(features: [])
    member = members(:john)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member is not active" do
    member = members(:aria)

    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member already has a new_member_fee invoice" do
    travel_to "2023-05-01"
    member = members(:john)

    assert_difference -> { member.invoices.count }, 1 do
      invoice(member)
    end
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member is still on trial basket" do
    member = members(:jane)

    assert_equal "2024-04-11", member.baskets.trial.last.delivery.date.to_s

    travel_to "2024-04-11"
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end

  test "do nothing if member first non-trial basket is no more recent" do
    member = members(:jane)

    assert_equal "2024-04-11", member.baskets.trial.last.delivery.date.to_s

    travel_to member.baskets.trial.last.delivery.date + 3.weeks + 1.day
    assert_no_difference -> { member.invoices.count } do
      invoice(member)
    end
  end
end

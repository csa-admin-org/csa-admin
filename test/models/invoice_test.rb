# frozen_string_literal: true

require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  test "set local currency code on initialize" do
    org(local_currency_code: "RAD", features: [ "local_currency" ])
    member = members(:john)
    member.update!(use_local_currency: true)

    invoice = create_annual_fee_invoice(member: member)
    assert_equal "RAD", invoice.currency_code
  end

  test "set local currency code for membership invoice" do
    org(local_currency_code: "RAD", features: [ "local_currency" ])
    member = members(:john)
    member.update!(use_local_currency: true)

    invoice = create_membership_invoice(member: member)
    assert_equal "RAD", invoice.currency_code
  end

  test "set local currency code for annual fee invoice when membership_annual_fee_only" do
    org(local_currency_code: "RAD", features: [ "local_currency" ], local_currency_membership_annual_fee_only: true)
    member = members(:john)
    member.update!(use_local_currency: true)

    invoice = create_annual_fee_invoice(member: member)
    assert_equal "RAD", invoice.currency_code
  end

  test "do not set local currency code for other entity types when membership_annual_fee_only" do
    org(local_currency_code: "RAD", features: [ "local_currency" ], local_currency_membership_annual_fee_only: true)
    member = members(:john)
    member.update!(use_local_currency: true)

    invoice = create_invoice(
      member: member,
      entity_type: "Other",
      items_attributes: {
        "0" => { description: "A custom item", amount: 100 }
      }
    )
    assert_equal "CHF", invoice.currency_code
  end

  test "set local currency code for other entity types when membership_annual_fee_only is false" do
    org(local_currency_code: "RAD", features: [ "local_currency" ], local_currency_membership_annual_fee_only: false)
    member = members(:john)
    member.update!(use_local_currency: true)

    invoice = create_invoice(
      member: member,
      entity_type: "Other",
      items_attributes: {
        "0" => { description: "A custom item", amount: 100 }
      }
    )
    assert_equal "RAD", invoice.currency_code
  end

  test "do not update currency code on update" do
    org(local_currency_code: "RAD", features: [ "local_currency" ])
    invoice = invoices(:annual_fee)
    invoice.member.update!(use_local_currency: true)

    assert_no_changes -> { invoice.reload.currency_code } do
      invoice.update!(sent_at: Time.now)
    end
  end

  test "ensure organization IBAN presence" do
    org(iban: nil)
    invoice = Invoice.new
    assert_not invoice.valid?
    assert_includes invoice.errors[:base], "Your IBAN number is not configured"
  end
end

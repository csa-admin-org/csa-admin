# frozen_string_literal: true

require "application_system_test_case"

class Members::BillingTest < ApplicationSystemTestCase
  test "list open invoices" do
    login(members(:martha))
    invoice = invoices(:annual_fee)

    visit "/billing"

    assert_text "Billing\n⤷ 1 open invoice"

    assert_text "To payCHF 30.00"
    assert_text "Annual feeCHF 30.00"
    assert_text "Payment intervalAnnual"

    assert_text "Open invoices"
    assert_text "01.04.24Invoice ##{invoice.id} (Annual fee) CHF 30.00"

    assert_text "History"
    assert_text "No invoice or payment at the moment."
    assert_text "Payments with reference numbers are processed automatically overnight. Please contact us if one of your payments does not appear."
  end

  test "list invoices and payments history" do
    travel_to "2024-05-01"
    member = members(:john)
    memberships(:john).update!(billing_year_division: 4)
    login(member)
    invoice = invoices(:other_closed)
    create_payment(amount: 42)

    visit "/billing"

    assert_text "Billing\n⤷ View history"

    assert_text "CreditCHF 42.00"
    assert_text "Annual feeCHF 30.00"
    assert_text "Payment intervalQuarterly"

    assert_text "Membership 2024"
    assert_text "Baskets10x 20.00 200.00"
    assert_text "CHF 200.00"
    assert_text "Already invoiced- 0.00"
    assert_text "Remaining to invoiceCHF 200.00"

    assert_text "History"
    assert_text "01.05.24Payment without reference-CHF 42.00"
    assert_text "02.04.24Payment of invoice #901871612-CHF 10.00"
    assert_text "01.04.24Invoice ##{invoice.id} (Other) CHF 10.00"
    assert_text "Payments with reference numbers are processed automatically overnight. Please contact us if one of your payments does not appear."
  end
end

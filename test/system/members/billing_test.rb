# frozen_string_literal: true

require "application_system_test_case"

class Members::BillingTest < ApplicationSystemTestCase
  test "list open invoices" do
    login(members(:martha))
    invoice = invoices(:annual_fee)

    visit "/billing"

    assert_text "Billing\n⤷ 1 open invoice"
    assert_text "1 open invoice"
    assert_text "01.04.24Open invoice ##{invoice.id} (Annual fee) CHF 30.00"
    assert_text "Amount remaining to be paidCHF 30.00"
    assert_text "Payment intervalAnnual"
  end

  test "list invoices and payments history" do
    travel_to "2024-05-01"
    member = members(:john)
    memberships(:john).update!(billing_year_division: 4)
    login(member)
    invoice = invoices(:other_closed)
    create_payment(amount: 42)

    visit "/billing"

    assert_text "History"
    assert_text "CreditCHF 42.00"
    assert_text "Payment intervalQuarterly"
    assert_text "01.05.24Payment without reference-CHF 42.00"
    assert_text "02.04.24Payment of invoice #901871612-CHF 10.00"
    assert_text "01.04.24Invoice ##{invoice.id} (Other) CHF 10.00"
  end
end

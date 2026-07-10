# frozen_string_literal: true

require "application_system_test_case"

class InvoicesTest < ApplicationSystemTestCase
  test "explains why an older entity invoice cannot be canceled" do
    enable_invoice_pdf
    travel_to "2024-01-01"
    invoice = create_membership_invoice(membership_amount_fraction: 2)
    create_membership_invoice

    login admins(:ultra)
    visit invoice_path(invoice)

    assert_button "Cancel", disabled: true
    assert_selector "button.action-item-button:disabled:not(.destructive)", text: "Cancel"
    assert_selector "[data-tooltip-target='content']",
      text: "This invoice cannot be canceled because a more recent invoice exists for the same membership or participation. Cancel or delete the most recent invoice first.",
      visible: :all
    assert_no_selector "form[action='#{cancel_invoice_path(invoice)}']"
  end

  test "shows manual SEPA XML export when bank connection cannot upload" do
    enable_invoice_pdf
    BankConnection.delete_all
    german_org(sepa_creditor_identifier: "DE98ZZZ09999999999")
    BankConnection.create!(
      provider: "bas",
      active: true,
      state: "ready",
      credentials: { account_number: "123", contract_password: "secret" })
    member = members(:anna)
    member.update!(language: "de", country_code: "DE")
    member.sepa_mandates.create!(
      iban: "DE21500500009876543210",
      umr: "123456",
      signed_on: Date.parse("2023-12-24"),
      source: "admin")
    member.reload
    invoice = create_annual_fee_invoice(member: member)

    login admins(:ultra)

    visit invoice_path(invoice)

    assert_selector "a[href='#{sepa_pain_invoice_path(invoice)}']", text: "SEPA Direct Debit (XML)"
    assert_no_text "Send order to the bank"

    visit invoices_path(scope: "open")
    sepa_pain_all_path = sepa_pain_all_invoices_path(scope: "open")

    assert_selector "a[href='#{sepa_pain_all_path}']", text: "SEPA Direct Debit (XML)"
  end

  test "creates an invoice for a rejected activity participation" do
    enable_invoice_pdf
    travel_to "2024-09-01"
    participation = activity_participations(:john_harvest)
    participation.reject!(admins(:super))

    login admins(:ultra)

    visit activity_participation_path(participation)
    click_link "Invoice"

    fill_in "Comment", with: "Forgot to come."
    perform_enqueued_jobs do
      click_button "Create Invoice"
    end

    assert_text "Member John Doe"
    assert_text "Object Participation ##{participation.id}"
    assert_text "Number / Participants 2"
    assert_text "Open"
    assert_text "Sent No"
    assert_text "Amount CHF 100.00"
    assert_text "Comment\nForgot to come."
  end
end

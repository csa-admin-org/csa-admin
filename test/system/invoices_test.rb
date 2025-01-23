# frozen_string_literal: true

require "application_system_test_case"

class InvoicesTest < ApplicationSystemTestCase
  test "creates an invoice for a rejected activity participation" do
    enable_invoice_pdf
    travel_to "2024-09-01"
    participation = activity_participations(:john_harvest)
    participation.reject!(admins(:super))

    login admins(:master)

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

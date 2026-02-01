# frozen_string_literal: true

require "application_system_test_case"

class Members::DeletionRequestsTest < ApplicationSystemTestCase
  test "eligible member sees request code button and explanation" do
    member = members(:mary) # inactive member
    login(member)

    visit new_members_account_deletion_request_path

    assert_equal "/account/delete", current_path
    assert_text "Delete my account"
    assert_text "You are about to request the deletion of your account"
    assert_text "What happens when you delete your account?"
    assert_text "You will be logged out immediately"
    assert_text "Your personal data will be anonymized after 30 days"
    assert_text "Your invoices are retained for tax purposes"
    assert_button "Request confirmation code"
    assert_link "Cancel"
  end

  test "ineligible member sees reasons and no request button" do
    member = members(:john) # active member
    login(member)

    visit new_members_account_deletion_request_path

    assert_equal "/account/delete", current_path
    assert_text "Delete my account"
    assert_text "Your account cannot be deleted at this time"
    assert_text "Your account is not inactive"
    assert_no_button "Request confirmation code"
    assert_link "Back"
  end

  test "requesting code sends email and redirects to confirmation" do
    member = members(:mary)
    login(member)

    visit new_members_account_deletion_request_path

    assert_difference -> { SessionMailer.deliveries.size }, 1 do
      click_button "Request confirmation code"
      perform_enqueued_jobs
    end

    assert_equal "/account/delete/confirm", current_path
    assert_text "A confirmation code has been sent to mary@doe.com"
  end

  test "cancel link returns to account page" do
    member = members(:mary)
    login(member)

    visit new_members_account_deletion_request_path
    click_link "Cancel"

    assert_equal "/account", current_path
  end

  test "back link returns to account page for ineligible member" do
    member = members(:john)
    login(member)

    visit new_members_account_deletion_request_path
    click_link "Back"

    assert_equal "/account", current_path
  end

  test "deletion email contains 6-digit code and expiry notice" do
    member = members(:mary)
    login(member)

    visit new_members_account_deletion_request_path
    click_button "Request confirmation code"
    perform_enqueued_jobs

    open_email("mary@doe.com")
    assert_equal "Confirm your account deletion", current_email.subject
    email_body = current_email.body.to_s
    assert_match(/\d{6}/, email_body)
    assert_match(/15 minutes/, email_body)
  end
end

# frozen_string_literal: true

require "application_system_test_case"

class Members::DeletionConfirmationsTest < ApplicationSystemTestCase
  def request_deletion_code(member)
    login(member)
    session = member.sessions.last
    visit new_members_account_deletion_request_path
    click_button "Request confirmation code"
    perform_enqueued_jobs
    session.reload
  end

  def extract_code_from_email(email_address)
    open_email(email_address)
    email_body = current_email.body.to_s
    # The code is wrapped in <strong> tags inside the highlight block
    match = email_body.match(/<strong>(\d{6})<\/strong>/)
    match[1]
  end

  test "confirmation page shows code input and explanation" do
    member = members(:mary)
    request_deletion_code(member)

    assert_equal "/account/delete/confirm", current_path
    assert_text "Confirm deletion"
    assert_text "A confirmation code has been sent to mary@doe.com"
    assert_text "What happens when you delete your account?"
    assert_text "You will be logged out immediately"
    assert_text "Your personal data will be anonymized after 30 days"
    assert_text "Your invoices are retained for tax purposes"
    assert_selector "input[name='code']"
    assert_button "Delete my account"
    assert_link "Cancel"
  end

  test "cancel link returns to account page" do
    member = members(:mary)
    request_deletion_code(member)

    click_link "Cancel"

    assert_equal "/account", current_path
  end

  test "valid code deletes account and shows goodbye page" do
    member = members(:mary)
    session = request_deletion_code(member)
    code = extract_code_from_email("mary@doe.com")

    fill_in "code", with: code
    click_button "Delete my account"

    assert_equal "/goodbye", current_path
    assert_text "Goodbye!"
    assert_text "Your account has been deleted"

    # Verify member is discarded
    assert member.reload.discarded?
    assert session.reload.revoked?
  end

  test "invalid code shows error and redirects to request page" do
    member = members(:mary)
    request_deletion_code(member)

    fill_in "code", with: "000000"
    click_button "Delete my account"

    assert_equal "/account/delete", current_path
    assert_text "The code is invalid or expired. Please request a new one."

    # Member should not be discarded
    assert_not member.reload.discarded?
  end

  test "original code is invalidated after failed attempt" do
    member = members(:mary)
    request_deletion_code(member)
    original_code = extract_code_from_email("mary@doe.com")

    # Submit wrong code - this touches updated_at and invalidates the code
    fill_in "code", with: "000000"
    click_button "Delete my account"

    # Wait to ensure timestamp changes (codes use updated_at.to_i)
    travel 1.second

    # Request new code - this touches updated_at again
    click_button "Request confirmation code"
    perform_enqueued_jobs

    # Try to use original code - should fail because updated_at changed
    fill_in "code", with: original_code
    click_button "Delete my account"

    assert_equal "/account/delete", current_path
    assert_text "The code is invalid or expired"
  end

  test "full deletion flow prevents subsequent login" do
    member = members(:mary)
    request_deletion_code(member)
    code = extract_code_from_email("mary@doe.com")

    fill_in "code", with: code
    click_button "Delete my account"

    assert_equal "/goodbye", current_path

    # Try to login again
    visit "/login"
    fill_in "session_email", with: "mary@doe.com"
    click_button "Send"

    assert_selector "span.error", text: "Unknown email"
  end
end

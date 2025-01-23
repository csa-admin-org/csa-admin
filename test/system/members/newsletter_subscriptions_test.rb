# frozen_string_literal: true

require "application_system_test_case"

class Members::NewsletterSubscriptionsTest < ApplicationSystemTestCase
  setup { postmark_client.reset! }

  test "unsubscribe with valid token and subscribe back" do
    email = "john@doe.com"
    token = Newsletter::Audience.encrypt_email(email)

    assert_difference -> { EmailSuppression.active.count } do
      visit "/newsletters/unsubscribe/#{token}"
    end

    suppression = EmailSuppression.active.last
    assert_equal email, suppression.email
    assert_equal "ManualSuppression", suppression.reason
    assert_equal "Customer", suppression.origin

    assert_text "👋🏻Your email (j...n@do...om) has been removed from the mailing list."
    assert_equal [
      [ :create_suppressions, "broadcast", email ]
    ], postmark_client.calls


    assert_difference -> { EmailSuppression.active.count }, -1 do
      click_button "I want to subscribe again."
    end
    assert_predicate suppression.reload.unsuppressed_at, :present?
    assert_text "🤗Your email (j...n@do...om) has been added back to the mailing list."

    assert_equal [
      [ :create_suppressions, "broadcast", email ],
      [ :delete_suppressions, "broadcast", email ]
    ], postmark_client.calls
  end

  test "unsubscribe with valid token (short email)" do
    email = "joe@do.com"
    members(:john).update!(emails: email)
    token = Newsletter::Audience.encrypt_email(email)

    assert_difference -> { EmailSuppression.active.count } do
      visit "/newsletters/unsubscribe/#{token}"
    end

    assert_text "(j...e@do...om)"
  end

  test "unsubscribe with invalid token" do
    assert_no_changes -> { EmailSuppression.active.count } do
      visit "/newsletters/unsubscribe/foo"
    end

    assert_equal 404, page.status_code
    assert_text "😬This link has expired or is invalid."
  end

  test "unsubscribe with email no more link to a member" do
    email = "unknown@unknown.com"
    token = Newsletter::Audience.encrypt_email(email)

    assert_no_changes -> { EmailSuppression.active.count } do
      visit "/newsletters/unsubscribe/#{token}"
    end

    assert_equal 404, page.status_code
    assert_text "😬This link has expired or is invalid."
  end
end

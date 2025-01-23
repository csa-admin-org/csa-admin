# frozen_string_literal: true

require "application_system_test_case"

class Members::EmailSuppressionsTest < ApplicationSystemTestCase
  test "subscribe back to newsletters" do
    member = members(:john)
    suppression = suppress_email("john@doe.com",
      stream_id: "broadcast",
      origin: "Customer",
      reason: "ManualSuppression")
    login(member)

    visit "/account"

    assert_changes -> { suppression.reload.unsuppressed_at }, from: nil do
      click_on "I would like to subscribe to the newsletter again"
    end

    assert_equal "/account", current_path
    assert_selector ".flash", text: "Thank you for subscribing to our newsletter again!"
    assert_no_text "I would like to subscribe to the newsletter again"
  end
end

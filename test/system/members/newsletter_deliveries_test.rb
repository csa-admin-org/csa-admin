# frozen_string_literal: true

require "application_system_test_case"

class Members::NewsletterDeliveriesTest < ApplicationSystemTestCase
  test "list received newsletters" do
    login(members(:john))

    assert_includes menu_nav, "Newsletters\n" + "⤷ 1 April 2024"
    click_on "Newsletters"

    assert_text "Subject John Doe"
    assert_text "1 April 2024"
  end

  test "subscribe back to newsletters" do
    member = members(:john)
    suppression = suppress_email("john@doe.com",
      stream_id: "broadcast",
      origin: "Customer",
      reason: "ManualSuppression")
    login(member)

    assert_includes menu_nav, "Newsletters\n" + "⤷ Subscribe!"

    click_on "Newsletters"

    assert_text "john@doe.com is not subscribed"
    assert_changes -> { suppression.reload.unsuppressed_at }, from: nil do
      click_on "Subscribe"
    end

    assert_selector ".flash", text: "Thank you for subscribing to the newsletter!"
    assert_no_text "john@doe.com is not subscribed"
  end
end

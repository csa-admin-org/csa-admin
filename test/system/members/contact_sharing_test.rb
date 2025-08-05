# frozen_string_literal: true

require "application_system_test_case"

class Members::ContactSharingTest < ApplicationSystemTestCase
  setup { travel_to "2024-04-01" }

  test "accepts to share contact" do
    member = members(:john)

    login(member)

    assert_includes menu_nav, "Contact sharing\n" + "⤷ Our farm"

    click_on "Contact sharing"

    check "I agree to share my contact information with other members of my depot."
    click_button "Share"

    assert_selector ".flash", text: "Your contact information is now shared with other members of your depot!"
    assert_text "No other members are sharing their contact information at this time!"
  end

  test "lists other members contact" do
    member = members(:john)
    member.update!(contact_sharing: true)
    members(:anna).update!(contact_sharing: true)
    memberships(:anna).update!(depot_id: farm_id)

    login(member)
    visit "/contact_sharing"

    within "ul#members" do
      assert_no_text "John"
      assert_text "Anna Doe"
      assert_text "Nowhere 45"
    end

    assert_text "Please contact us by email if you want to stop sharing your contact information."
  end

  test "redirects when member is not active" do
    login(members(:martha))
    visit "/contact_sharing"

    assert_not_equal "/contact_sharing", current_path
  end

  test "redirects when contact_sharing is not a feature" do
    org(features: [])
    login(members(:john))
    visit "/contact_sharing"

    assert_not_equal "/contact_sharing", current_path
  end
end

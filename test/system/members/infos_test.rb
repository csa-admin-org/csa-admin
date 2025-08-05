# frozen_string_literal: true

require "application_system_test_case"

class Members::InfosTest < ApplicationSystemTestCase
  test "show informations link" do
    Current.org.update!(member_information_text: "Some confidential infos")
    login(members(:john))

    assert_selector "a", text: "Information"

    click_on "Information"

    assert_equal "/info", current_path
    assert_text "Information"
    assert_text "Some confidential infos"
  end

  test "show informations with custom title" do
    Current.org.update!(
      member_information_title: "Archive",
      member_information_text: "Some confidential archive infos")
    login(members(:john))

    assert_selector "a", text: "Archive"

    click_on "Archive"

    assert_equal "/info", current_path
    assert_text "Archive"
    assert_text "Some confidential archive infos"
  end

  test "do not show informations when not set" do
    Current.org.update!(member_information_text: nil)
    login(members(:john))

    assert_no_selector "a", text: "Information"

    visit "/info"
    assert_not_equal "/info", current_path
  end

  test "do not show informations when not logged in" do
    Current.org.update!(member_information_text: "Some confidential infos")

    visit "/info"
    assert_equal "/login", current_path
  end
end

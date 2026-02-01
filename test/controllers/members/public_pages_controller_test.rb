# frozen_string_literal: true

require "test_helper"

class Members::PublicPagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
    session
  end

  # Welcome page tests

  test "welcome page is accessible without authentication" do
    get members_public_page_path("welcome")

    assert_response :success
    assert_select "h1", /#{I18n.t("members.public_pages.welcome.title")}/
  end

  test "welcome page shows registration confirmation text" do
    get members_public_page_path("welcome")

    assert_response :success
    assert_select "p", /Your registration will be confirmed/
  end

  test "welcome page redirects logged-in member to home" do
    member = members(:john)
    login(member)

    get members_public_page_path("welcome")

    assert_redirected_to members_member_path
  end

  # Goodbye page tests

  test "goodbye page is accessible without authentication" do
    get members_public_page_path("goodbye")

    assert_response :success
    assert_select "h1", /#{I18n.t("members.public_pages.goodbye.title")}/
  end

  test "goodbye page shows deletion confirmation text" do
    get members_public_page_path("goodbye")

    assert_response :success
    assert_select "p", /Your account has been deleted/
  end

  test "goodbye page redirects logged-in member to home" do
    member = members(:john)
    login(member)

    get members_public_page_path("goodbye")

    assert_redirected_to members_member_path
  end
end

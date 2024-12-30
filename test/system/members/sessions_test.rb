# frozen_string_literal: true

require "application_system_test_case"

class Members::SessionsTest < ApplicationSystemTestCase
  test "creates a new session from email" do
    member = members(:john)

    visit "/"
    assert_equal "/login", current_path
    assert_text "Please log in to access your account."

    fill_in "session_email", with: " john@doe.com "
    click_button "Send"
    perform_enqueued_jobs

    session = member.sessions.last

    assert_equal "john@doe.com", session.email
    assert_equal 1, SessionMailer.deliveries.size

    assert_equal "/login", current_path
    assert_text "Thank you! An email has just been sent to you."

    open_email("john@doe.com")
    current_email.click_link "Access my account"

    assert_equal "/activity_participations", current_path
    assert_text "You are now logged in."

    delete_session(member)
    visit "/"

    assert_equal "/login", current_path
    assert_text "Please log in to access your account."
  end

  test "does not accept blank email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "session_email", with: ""
    click_button "Send"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "span.error", text: "can't be blank"
  end

  test "does not accept invalid email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "session_email", with: "foo@bar"
    click_button "Send"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "span.error", text: "is invalid"
  end

  test "does not accept unknown email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "session_email", with: "unknown@member.com"
    click_button "Send"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "span.error", text: "Unknown email"
  end

  test "does not accept old session when not logged in" do
    old_session = create_session(members(:john), created_at: 1.hour.ago)

    visit "/sessions/#{old_session.token}"

    assert_equal "/login", current_path
    assert_text "Your login link is no longer valid. Please request a new one."
  end

  test "handles old session when already logged in" do
    member = members(:john)
    login(member)
    old_session = create_session(member, created_at: 1.hour.ago)

    visit "/sessions/#{old_session.token}"

    assert_equal "/activity_participations", current_path
    assert_text "You are already logged in."
  end

  test "logout session without email" do
    member = members(:john)
    login(member)
    member.sessions.last.update!(email: nil)

    visit "/"

    assert_equal "/login", current_path
    assert_text "Please log in to access your account."
  end

  test "logout expired session" do
    member = members(:john)
    login(member)
    member.sessions.last.update!(created_at: 1.year.ago)

    visit "/"

    assert_equal "/login", current_path
    assert_text "Your session has expired, please log in again."

    visit "/"

    assert_equal "/login", current_path
    assert_text "Please log in to access your account."
  end

  test "update last usage column every hour when using the session" do
    member = members(:john)

    travel_to Time.new(2018, 7, 6, 1) do
      login(member)

      session = member.sessions.last
      assert_equal Time.new(2018, 7, 6, 1), session.last_used_at
      assert_equal "127.0.0.1", session.last_remote_addr
      assert_equal "Other", session.last_user_agent.to_s
    end

    travel_to Time.new(2018, 7, 6, 1, 59) do
      visit "/"
      assert_equal Time.new(2018, 7, 6, 1), member.sessions.last.last_used_at
    end

    travel_to Time.new(2018, 7, 6, 2, 0, 1) do
      visit "/"
      assert_equal Time.new(2018, 7, 6, 2, 0, 1), member.sessions.last.last_used_at
    end
  end

  test "revoke session on logout" do
    member = members(:john)
    login(member)
    session = member.sessions.last

    visit "/"

    assert_changes -> { session.reload.revoked_at }, from: nil do
      click_button "Logout"
    end

    visit "/"

    assert_equal "/login", current_path
    assert_text "Please log in to access your account."
  end
end

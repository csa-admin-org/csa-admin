# frozen_string_literal: true

require "application_system_test_case"

class SessionsTest < ApplicationSystemTestCase
  test "creates a new session from email" do
    admin = admins(:ultra)

    visit "/"

    assert_equal "/login", current_path
    assert_equal "Please log in to access your account.", flash_alert

    fill_in "Email", with: " info@csa-admin.org "
    click_button "Submit"
    perform_enqueued_jobs

    session = admin.sessions.last

    assert_equal "info@csa-admin.org", session.email
    assert_equal 1, SessionMailer.deliveries.size

    assert_equal "/login", current_path
    assert_equal "Thank you! An email has just been sent to you.", flash_notice

    open_email("info@csa-admin.org")
    current_email.click_link "Access my admin account"

    assert_equal "/", current_path
    assert_equal "You are now logged in.", flash_notice

    delete_session(admin)
    visit "/"

    assert_equal "/login", current_path
    assert_equal "Please log in to access your account.", flash_alert
  end

  test "does not accept blank email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "Email", with: ""
    click_button "Submit"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "p.inline-errors", text: "can't be blank"
  end

  test "does not accept invalid email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "Email", with: "@foo"
    click_button "Submit"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "p.inline-errors", text: "is invalid"
  end

  test "does not accept unknown email" do
    visit "/"
    assert_equal "/login", current_path

    fill_in "Email", with: "unknown@admin.com"
    click_button "Submit"
    perform_enqueued_jobs

    assert_equal 0, SessionMailer.deliveries.size

    assert_equal "/sessions", current_path
    assert_selector "p.inline-errors", text: "Unknown email"
  end

  test "cannot redeem old session token" do
    session = create_session(admins(:ultra))
    token = session.generate_token_for(:redeem)

    travel 15.minutes + 1.second
    visit "/sessions/#{token}"

    assert_equal "/login", current_path
    assert_equal "Your login link is no longer valid. Please request a new one.", flash_alert
  end

  test "cannot redeem sessions twice" do
    session = create_session(admins(:ultra))
    token = session.generate_token_for(:redeem)

    assert_changes -> { session.reload.last_used_at }, from: nil do
      visit "/sessions/#{token}"
    end
    assert_equal "You are now logged in.", flash_notice

    visit "/sessions/#{token}"
    assert_equal "Your login link is no longer valid. Please request a new one.", flash_alert
  end

  test "logout session without email" do
    admin = admins(:ultra)
    login(admin)
    admin.sessions.last.update!(email: nil)

    visit "/"

    assert_equal "/login", current_path
    assert_equal "Please log in to access your account.", flash_alert
  end

  test "logout expired session" do
    admin = admins(:ultra)
    login(admin)
    admin.sessions.last.update!(created_at: 1.year.ago)

    visit "/"

    assert_equal "/login", current_path
    assert_equal "Your session has expired, please log in again.", flash_alert

    visit "/"

    assert_equal "/login", current_path
    assert_equal "Please log in to access your account.", flash_alert
  end

  test "update last usage column every hour when using the session" do
    admin = admins(:ultra)

    travel_to Time.new(2018, 7, 6, 1) do
      login(admin)

      session = admin.sessions.last
      assert_equal Time.new(2018, 7, 6, 1), session.last_used_at
      assert_equal "127.0.0.1", session.last_remote_addr
      assert_equal "Other", session.last_user_agent.to_s
    end

    travel_to Time.new(2018, 7, 6, 1, 59) do
      visit "/"
      assert_equal Time.new(2018, 7, 6, 1), admin.sessions.last.last_used_at
    end

    travel_to Time.new(2018, 7, 6, 2, 0, 1) do
      visit "/"
      assert_equal Time.new(2018, 7, 6, 2, 0, 1), admin.sessions.last.last_used_at
    end
  end

  test "revoke session on logout" do
    admin = admins(:ultra)
    login(admin)
    session = admin.sessions.last

    visit "/"

    assert_changes -> { session.reload.revoked_at }, from: nil do
      click_link "Logout"
    end

    visit "/"

    assert_equal "/login", current_path
    assert_equal "Please log in to access your account.", flash_alert
  end
end

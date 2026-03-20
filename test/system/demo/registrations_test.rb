# frozen_string_literal: true

require "application_system_test_case"

class Demo::RegistrationsTest < ApplicationSystemTestCase
  setup do
    Capybara.app_host = "http://admin.acme.test"
  end

  test "redirects to login on non-demo tenant" do
    visit new_demo_registration_path

    assert_equal "/login", current_path
  end

  test "renders registration form on demo tenant" do
    with_demo_tenant do
      visit new_demo_registration_path

      assert_text "Try the Demo"
      assert_selector "input[name='demo_registration[name]']"
      assert_selector "input[name='demo_registration[email]']"
      assert_selector "textarea[name='demo_registration[note]']"
    end
  end

  test "successful registration redirects with flash and sends login email" do
    with_demo_tenant do
      visit new_demo_registration_path

      fill_in "Your name", with: "Alice Johnson"
      fill_in "Email", with: "alice@example.com"
      fill_in "Your CSA", with: "Green Valley CSA"
      fill_in_hashcash
      click_button "Get started"
      perform_enqueued_jobs

      assert_equal "/login", current_path
      assert_text "Check your email! A login link has been sent to you."

      open_email("alice@example.com")
      current_email.click_link "Access the demo"

      assert_text "You are now logged in."
    end
  end

  test "shows error with blank name" do
    with_demo_tenant do
      visit new_demo_registration_path

      fill_in "Email", with: "test@example.com"
      fill_in_hashcash
      click_button "Get started"

      assert_selector "p.inline-errors", text: "can't be blank"
    end
  end

  test "shows error with invalid email" do
    with_demo_tenant do
      visit new_demo_registration_path

      fill_in "Your name", with: "Test User"
      fill_in "Email", with: "not-an-email"
      fill_in_hashcash
      click_button "Get started"

      assert_selector "p.inline-errors", text: "is invalid"
    end
  end

  test "shows error with existing email" do
    with_demo_tenant do
      Admin.create!(
        name: "Existing",
        email: "existing@example.com",
        language: "en",
        permission: Permission.superadmin)

      visit new_demo_registration_path

      fill_in "Your name", with: "Another User"
      fill_in "Email", with: "existing@example.com"
      fill_in_hashcash
      click_button "Get started"

      assert_selector "p.inline-errors", text: "has already been taken"
    end
  end

  test "rejects registration without hashcash" do
    with_demo_tenant do
      visit new_demo_registration_path

      fill_in "Your name", with: "Alice Johnson"
      fill_in "Email", with: "alice@example.com"

      assert_no_difference "Admin.count" do
        click_button "Get started"
      end

      assert_text "Security verification failed, please try again."
    end
  end

  test "login link navigates to registration form" do
    with_demo_tenant do
      visit new_demo_registration_path

      click_link "Log in"

      assert_equal "/login", current_path
    end
  end
end

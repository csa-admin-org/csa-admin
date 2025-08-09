# frozen_string_literal: true

require "application_system_test_case"

class MissionControl::SessionsTest < ApplicationSystemTestCase
  def authenticate!(password: "password")
    credentials = ActionController::HttpAuthentication::Basic.encode_credentials("mc", password)
    page.driver.header "Authorization", credentials
  end

  test "authenticates via http basic" do
    visit "/sessions/foo"

    assert_equal 401, page.status_code
  end

  test "invalid password" do
    authenticate!(password: "wrong")

    visit "/sessions/foo"

    assert_equal 401, page.status_code
  end

  test "invalid tenant" do
    authenticate!

    assert_raise RuntimeError, match: "Unknown tenant 'foo'" do
      visit "/sessions/foo"
    end
  end

  test "creates ultra admin session for tenant" do
    authenticate!

    assert_difference "Session.count" do
      visit "/sessions/acme"
    end

    assert_equal "http://admin.acme.test/", current_url
    assert_equal "You are now logged in.", flash_notice
  end
end

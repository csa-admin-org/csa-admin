# frozen_string_literal: true

require "test_helper"

class ActivityParticipationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "index shows calendar subscribe link when icalendar_auth_token is present" do
    travel_to "2024-01-01"
    login admins(:super)

    get activity_participations_path

    assert_response :success
    assert_select "#calendar_sidebar_section"
  end

  test "index succeeds when icalendar_auth_token cannot be decrypted" do
    travel_to "2024-01-01"
    login admins(:super)
    corrupt_icalendar_auth_token!

    get activity_participations_path

    assert_response :success
    assert_select "#calendar_sidebar_section", false
  end
end

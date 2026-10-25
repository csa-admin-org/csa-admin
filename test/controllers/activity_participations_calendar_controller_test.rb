# frozen_string_literal: true

require "test_helper"

class ActivityParticipationsCalendarControllerTest < ActionDispatch::IntegrationTest
  def request(auth_token: nil)
    auth_token ||= Current.org.icalendar_auth_token
    host! "admin.acme.test"
    get "/activity_participations/calendar.ics", params: { auth_token: auth_token }
  end

  test "without auth token" do
    Current.org.update_column(:icalendar_auth_token, nil)
    request
    assert_response :unauthorized
  end

  test "with a wrong auth token" do
    request(auth_token: "wrong")
    assert_response :unauthorized
  end

  test "with a good auth token" do
    travel_to "2024-01-01"
    request
    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.headers["Content-Type"]
    assert_includes response.body, "John Doe (2)"
    assert_includes response.body, "Jane Doe"
    assert_includes response.body, "TZID:Europe/Zurich"
  end

  test "renders during the autumn DST fallback hour" do
    travel_to Time.zone.at(Time.utc(2024, 10, 27, 0, 1, 15))
    ActivityParticipation.update_all(updated_at: Time.current)
    request
    assert_response :success
    assert_includes response.body, "BEGIN:VTIMEZONE"
  end
end

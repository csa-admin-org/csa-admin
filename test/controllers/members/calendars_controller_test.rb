# frozen_string_literal: true

require "test_helper"

class Members::CalendarsControllerTest < ActionDispatch::IntegrationTest
  def request(token: nil, headers: {})
    host! "members.acme.test"
    get "/calendar.ics", params: { token: token }.compact, headers: headers
  end

  test "without token" do
    request token: nil
    assert_response :unauthorized
  end

  test "with a wrong token" do
    request token: "wrong"
    assert_response :unauthorized
  end

  test "with a good token" do
    request token: members(:john).generate_token_for(:calendar)

    assert_response :success
    assert_equal "text/calendar; charset=utf-8", response.headers["Content-Type"]
    lines = response.body.split("\r\n")

    assert_includes lines, "NAME:Acme"
    assert_includes lines, "X-WR-CALNAME:Acme"
    assert_includes lines, "URL;VALUE=URI:https://members.acme.test"
    assert_includes lines, "COLOR:#19A24A"
    assert_includes lines, "X-APPLE-CALENDAR-COLOR:#19A24A"
  end

  test "with unchanged calendar" do
    travel_to "2024-01-01"

    token = members(:john).generate_token_for(:calendar)
    request token: token
    last_modified = response.headers.fetch("Last-Modified")

    queries = []
    callback = ->(_name, _start, _finish, _id, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      request token: token, headers: { "If-Modified-Since" => last_modified }
    end

    assert_response :not_modified
    assert_empty response.body
    assert_not queries.any? { |sql| sql.include?('SELECT "activity_participations".*') }
    assert_not queries.any? { |sql| sql.include?('SELECT "activities".*') }
  end

  test "uses the response last modified time in the ICS body" do
    travel_to "2024-01-01"

    member = members(:john)
    timestamp = Time.zone.local(2024, 1, 2, 12)
    Basket.unscoped.joins(:membership)
      .where(memberships: { member_id: member.id })
      .update_all(updated_at: timestamp - 1.minute)
    ActivityParticipation.where(member: member).update_all(updated_at: timestamp - 1.minute)
    activity_participations(:john_harvest).update_column(:updated_at, timestamp)

    request token: member.generate_token_for(:calendar)

    assert_equal timestamp.httpdate, response.headers["Last-Modified"]
    assert_includes response.body,
      "LAST-MODIFIED;VALUE=DATE-TIME:#{timestamp.strftime("%Y%m%dT%H%M%S")}"
  end

  test "with basket" do
    travel_to "2024-01-01"

    request token: members(:john).generate_token_for(:calendar)

    lines = response.body.split("\r\n")
    assert_includes lines, "SUMMARY:Basket Acme"
    assert_includes lines, "DTSTART;VALUE=DATE:20240401"
    assert_includes lines, "DTEND;VALUE=DATE:20240401"
    assert_includes lines, "CLASS:PRIVATE"
    assert_includes lines, "LOCATION:42 Nowhere\\, 1234 Unknown"
    assert_includes lines, "DESCRIPTION:Basket: Medium basket\\nDepot: Farm"
  end

  test "with activity participation" do
    travel_to "2024-01-01"

    request token: members(:john).generate_token_for(:calendar)

    lines = response.body.split("\r\n")
    assert_includes lines, "SUMMARY:Help with the harvest (Acme)"
    assert_includes lines, "DTSTART;TZID=Europe/Zurich:20240701T083000"
    assert_includes lines, "DTEND;TZID=Europe/Zurich:20240701T120000"
    assert_includes lines, "URL;VALUE=URI:https://farm.example.com"
    assert_includes lines, "LOCATION:Farm"
    assert_includes lines, "CLASS:PRIVATE"
    assert_includes lines, "DESCRIPTION:Participants: 2\\n\\nPicking vegetables\\n\\nCarpooling:\\n- +41 79 "
  end
end

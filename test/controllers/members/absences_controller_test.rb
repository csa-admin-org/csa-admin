# frozen_string_literal: true

require "test_helper"

class Members::AbsencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    org(features: [ :absence ])
  end

  test "does not offer to cancel an absence that started last fiscal year" do
    absence = travel_to("2023-12-01") {
      create_absence(
        member: members(:john),
        started_on: "2023-12-15",
        ended_on: "2024-06-15")
    }
    travel_to "2024-06-01"
    Current.reset
    login members(:john)

    get members_absences_path

    assert_response :success
    assert_select "form[action='#{members_absence_path(absence)}']", count: 0
  end

  test "cannot cancel an absence that started last fiscal year" do
    absence = travel_to("2023-12-01") {
      create_absence(
        member: members(:john),
        started_on: "2023-12-15",
        ended_on: "2024-06-15")
    }
    travel_to "2024-06-01"
    Current.reset
    login members(:john)

    assert_no_difference "Absence.count" do
      delete members_absence_path(absence)
    end
    assert_response :not_found
  end

  test "can still cancel a current fiscal year absence" do
    travel_to "2024-06-01"
    absence = create_absence(
      member: members(:john),
      started_on: "2024-06-10",
      ended_on: "2024-06-20")
    login members(:john)

    assert_difference "Absence.count", -1 do
      delete members_absence_path(absence)
    end
    assert_redirected_to members_absences_path
  end

  private

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end

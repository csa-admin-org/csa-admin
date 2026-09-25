# frozen_string_literal: true

require "test_helper"

class AbsencesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  test "hides edit and destroy for an absence that ended last fiscal year" do
    absence = past_absence
    travel_to "2024-06-01"
    Current.reset

    get absence_path(absence)

    assert_response :success
    assert_select "a[href='#{edit_absence_path(absence)}']", count: 0
    assert_select "form[action='#{absence_path(absence)}'] button.destructive-icon-action", count: 0
    assert_select "form.comment-form"
  end

  test "cannot update or destroy an absence that ended last fiscal year" do
    absence = past_absence
    travel_to "2024-06-01"
    Current.reset

    get edit_absence_path(absence)
    assert_redirected_to root_path

    patch absence_path(absence), params: { absence: { note: "Changed" } }
    assert_redirected_to root_path
    assert_equal "Holiday", absence.reload.note

    assert_no_difference "Absence.count" do
      delete absence_path(absence)
    end
    assert_redirected_to root_path
  end

  test "a spanning absence can be edited but not destroyed" do
    absence = spanning_absence
    travel_to "2024-06-01"
    Current.reset

    get absence_path(absence)

    assert_response :success
    assert_select "a[href='#{edit_absence_path(absence)}']"
    assert_select "form[action='#{absence_path(absence)}'] button.destructive-icon-action", count: 0

    get edit_absence_path(absence)

    assert_response :success
    assert_select "#absence_started_on[disabled]"
    assert_select "#absence_ended_on[min='2023-12-31']"
    assert_select "#absence_note"

    assert_no_difference "Absence.count" do
      delete absence_path(absence)
    end
    assert_redirected_to root_path
  end

  test "a current fiscal year absence stays editable and destroyable" do
    travel_to "2024-06-01"
    absence = create_absence(started_on: "2024-06-10", ended_on: "2024-06-20", note: "Trip")

    get absence_path(absence)

    assert_response :success
    assert_select "a[href='#{edit_absence_path(absence)}']"
    assert_select "form[action='#{absence_path(absence)}'] button.destructive-icon-action"

    get edit_absence_path(absence)

    assert_response :success
    assert_select "#absence_started_on[disabled]", count: 0
    assert_select "#absence_started_on[min='2024-01-01']"

    patch absence_path(absence), params: {
      absence: { started_on: "2024-07-01", ended_on: "2024-07-08", note: "Later" }
    }

    assert_redirected_to absence_path(absence)
    assert_equal Date.new(2024, 7, 1), absence.reload.started_on
    assert_equal "Later", absence.note

    assert_difference "Absence.count", -1 do
      delete absence_path(absence)
    end
  end

  test "cannot create an absence that starts last fiscal year" do
    travel_to "2024-06-01"

    assert_no_difference "Absence.count" do
      post absences_path, params: {
        absence: {
          member_id: members(:john).id,
          started_on: "2023-12-01",
          ended_on: "2023-12-15"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_includes response.body, "must be in the current fiscal year"
  end

  test "cannot move a current absence so that it starts last fiscal year" do
    travel_to "2024-06-01"
    absence = create_absence(started_on: "2024-06-10", ended_on: "2024-06-20")

    patch absence_path(absence), params: {
      absence: { started_on: "2023-12-20", ended_on: "2024-06-20" }
    }

    assert_response :unprocessable_entity
    assert_equal Date.new(2024, 6, 10), absence.reload.started_on
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  def past_absence
    travel_to("2023-06-01") {
      create_absence(started_on: "2023-06-01", ended_on: "2023-06-15", note: "Holiday")
    }
  end

  def spanning_absence
    travel_to("2023-12-01") {
      create_absence(started_on: "2023-12-15", ended_on: "2024-01-15", note: "Away")
    }
  end
end

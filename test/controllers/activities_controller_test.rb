# frozen_string_literal: true

require "test_helper"

class ActivitiesControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    travel_to "2024-09-11"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "new form selects bulk dates and disables unique date server-side" do
    get new_activity_path

    assert_response :success
    assert_select "a[aria-controls=bulk_dates][aria-selected=true]"
    assert_select "a[aria-controls=unique_date][aria-selected=false]"
    assert_select "fieldset#bulk_dates:not([disabled])"
    assert_select "fieldset#unique_date[disabled]"
    assert_select "input#activity_bulk_dates_starts_on[required]"
    assert_select "input#activity_bulk_dates_ends_on[required]"
    assert_select "select#activity_bulk_dates_weeks_frequency[required]"
    assert_select "input#activity_date[required]"
  end

  test "creates a unique date even when leftover bulk dates are submitted" do
    assert_difference -> { Activity.count }, 1 do
      post activities_path, params: {
        activity: {
          date: "2024-09-18",
          bulk_dates_starts_on: "2024-09-11",
          bulk_dates_ends_on: "",
          bulk_dates_weeks_frequency: "",
          bulk_dates_wdays: [ "" ],
          start_time: "09:00",
          end_time: "12:00",
          preset_id: activity_presets(:harvest).id,
          participants_limit: 3,
          visible: true
        }
      }
    end

    activity = Activity.last
    assert_redirected_to activities_path
    assert_equal Date.new(2024, 9, 18), activity.date
    assert_nil activity.bulk_dates_starts_on
  end

  test "renders inline bulk date errors on the selected tab" do
    assert_no_difference -> { Activity.count } do
      post activities_path, params: {
        activity: {
          bulk_dates_starts_on: "",
          bulk_dates_ends_on: "",
          bulk_dates_weeks_frequency: "",
          bulk_dates_wdays: [ "" ],
          start_time: "09:00",
          end_time: "12:00",
          preset_id: activity_presets(:harvest).id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "ul.errors", count: 0
    assert_select "a[aria-controls=bulk_dates][aria-selected=true]"
    assert_select "fieldset#bulk_dates:not([disabled])"
    assert_select "fieldset#unique_date[disabled]"
    assert_select "li#activity_bulk_dates_starts_on_input p.inline-errors"
    assert_select "li#activity_bulk_dates_ends_on_input p.inline-errors"
    assert_select "li#activity_bulk_dates_weeks_frequency_input p.inline-errors"
    assert_select "li#activity_bulk_dates_wdays_input p.inline-errors"
  end

  test "keeps unique date selected after another field is invalid" do
    assert_no_difference -> { Activity.count } do
      post activities_path, params: {
        activity: {
          date: "2024-09-18",
          bulk_dates_starts_on: "2024-09-11",
          start_time: "12:00",
          end_time: "08:00",
          preset_id: activity_presets(:harvest).id
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-controls=unique_date][aria-selected=true]"
    assert_select "fieldset#unique_date:not([disabled])"
    assert_select "fieldset#bulk_dates[disabled]"
    assert_select "input#activity_date[value='2024-09-18']"
    assert_select "li#activity_end_time_input p.inline-errors"
  end
end

# frozen_string_literal: true

require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
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

  test "renders the two-week calendar with busy days" do
    travel_to "2024-04-01"
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar"
    assert_select ".calendar-day", count: 14
    assert_select ".calendar-day.is-today", count: 1
    assert_select ".calendar-day.is-event", count: 5
    assert_select ".calendar-day.is-event a.calendar-date", text: "1"
    assert_select ".calendar-day.is-event a.calendar-date", text: "4"
    assert_select ".calendar-day.is-event a.calendar-date", text: "5"
    assert_select ".calendar-day.is-event a.calendar-date", text: "8"
    assert_select ".calendar-day.is-event a.calendar-date", text: "11"
    assert_select ".calendar-count svg", minimum: 1
    assert_select ".calendar-count", text: "–", count: 0
    assert_select ".calendar-day.is-delivery a.calendar-date", minimum: 1
    assert_select "turbo-frame#dashboard_calendar[target='_top']"
    assert_select ".calendar-nav"
    assert_select ".calendar-nav-control.is-disabled", count: 1
    assert_select ".calendar-nav-control[href='/?week=2024-W13'][data-turbo-frame='dashboard_calendar'][data-turbo-action='advance']"
    assert_select ".calendar-nav-control[href='/?week=2024-W15'][data-turbo-frame='dashboard_calendar'][data-turbo-action='advance']"
    assert_select ".calendar-nav-range", text: "1 Apr–14 Apr"
  end

  test "pages the calendar by week" do
    travel_to "2024-04-01"
    login admins(:super)

    get root_path(week: "2024-W15")

    assert_response :success
    assert_select "turbo-frame#dashboard_calendar"
    assert_select ".calendar-day", count: 14
    assert_select ".calendar-day.is-today", count: 0
    assert_select ".calendar-day.is-event a.calendar-date", text: "8"
    assert_select ".calendar-day.is-event a.calendar-date", text: "11"
    assert_select ".calendar-day.is-event a.calendar-date", text: "15"
    assert_select ".calendar-nav-control[href='/'][data-turbo-frame='dashboard_calendar'][data-turbo-action='advance']"
    assert_select ".calendar-nav-control.is-disabled", count: 0
    assert_select ".calendar-nav-control[href='/?week=2024-W14'][data-turbo-frame='dashboard_calendar']"
    assert_select ".calendar-nav-control[href='/?week=2024-W16'][data-turbo-frame='dashboard_calendar']"
  end

  test "clamps a far-future week to the last busy Monday" do
    travel_to "2024-04-01"
    login admins(:super)

    get root_path(week: "2099-W01")

    assert_response :success
    assert_select ".calendar-day a.calendar-date", text: "9"
    assert_select ".calendar-nav-control.is-disabled", count: 1
    assert_select ".calendar-nav-control[href='/?week=2025-W23']"
  end

  test "ignores an invalid week param" do
    travel_to "2024-04-01"
    login admins(:super)

    get root_path(week: "nope")

    assert_response :success
    assert_select ".calendar-day.is-today", count: 1
    assert_select ".calendar-nav-control.is-disabled", count: 1
  end

  test "hides the calendar when the default fortnight is empty" do
    travel_to "2024-08-01"
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar", count: 0
    assert_select "turbo-frame#dashboard_calendar", count: 1
    assert_select "turbo-frame#dashboard_calendar .panel", count: 0
  end

  test "keeps a paged empty fortnight visible" do
    travel_to "2024-08-01"
    login admins(:super)

    get root_path(week: "2024-W32")

    assert_response :success
    assert_select "turbo-frame#dashboard_calendar"
    assert_select ".calendar-day", count: 14
    assert_select ".calendar-nav-control[href='/']"
  end

  test "links activity days through the activity date filter" do
    travel_to "2024-04-01"
    activity = create_activity(date: Date.new(2024, 4, 2))
    ActivityParticipation.create!(member: members(:martha), activity: activity, participants_count: 1)
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar-count[href*='activity_date_gteq']"
    assert_select ".calendar-count[href*='activity_id_in']", count: 0
  end

  test "mutes past days and keeps their counts" do
    travel_to "2024-04-04"
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar-day.is-past", minimum: 3
    assert_select ".calendar-day.is-past.is-delivery a.calendar-date", text: "1"
    assert_select ".calendar-day.is-past .calendar-count", minimum: 1
    assert_select ".calendar-day.is-today.is-event a.calendar-date", text: "4"
  end

  test "hides shop counters when the shop feature is off" do
    travel_to "2024-04-01"
    org(features: Current.org.features - [ :shop ])
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar-day.is-event", count: 4
    assert_select ".calendar-count[title='#{I18n.t("shop.title")}']", count: 0
  end

  test "hides activity counters when the activity feature is off" do
    travel_to "2024-04-01"
    create_activity(date: Date.new(2024, 4, 2))
    org(features: Current.org.features - [ :activity ])
    login admins(:super)

    get root_path

    assert_response :success
    assert_select ".calendar"
    assert_select ".calendar-count[title='#{I18n.t("activities.halfday_work.other")}']", count: 0
  end
end

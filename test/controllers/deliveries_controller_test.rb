# frozen_string_literal: true

require "test_helper"

class DeliveriesControllerTest < ActionDispatch::IntegrationTest
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
    get new_delivery_path

    assert_response :success
    assert_select "a[aria-controls=bulk_dates][aria-selected=true]"
    assert_select "fieldset#bulk_dates:not([disabled])"
    assert_select "fieldset#unique_date[disabled]"
    assert_select "input#delivery_bulk_dates_starts_on[required]"
    assert_select "input#delivery_date[required]"
    assert_select ".admin-info-pane", text: /not always the calendar year/
    assert_select ".admin-info-pane a[href='/handbook/deliveries#fiscal-year']"
    assert_select "#unique_date .delivery-fiscal-year"
    assert_select ".admin-warning-pane", text: /already started/, count: 0
    assert_select "button[type=submit][data-confirm]", count: 0
  end

  test "new delivery form shows the fiscal year of the entered date" do
    post deliveries_path, params: {
      delivery: {
        date: "2025-06-02",
        basket_size_price_percentage: -1
      }
    }

    assert_response :unprocessable_entity
    assert_select ".delivery-fiscal-year", text: I18n.t(
      "active_admin.resources.delivery.fiscal_year_of_date", year: "2025")
    assert_select "button[type=submit][data-confirm]", count: 0
  end

  test "fiscal year preview returns the fiscal year of a date" do
    get fiscal_year_deliveries_path(date: "2025-06-02")

    assert_response :success
    assert_select ".delivery-fiscal-year", text: I18n.t(
      "active_admin.resources.delivery.fiscal_year_of_date", year: "2025")
    assert_select ".delivery-fiscal-year[data-confirm=''][data-for-date='2025-06-02']"
  end

  test "fiscal year preview confirm matches the entered date" do
    date = Date.new(2024, 9, 16)
    count = Delivery.memberships_receiving_basket_count(date)

    get fiscal_year_deliveries_path(date: date.iso8601)

    assert_response :success
    preview = css_select(".delivery-fiscal-year").first
    assert_equal date.iso8601, preview["data-for-date"]
    assert_includes preview["data-confirm"], count.to_s
  end

  test "create confirm for a current fiscal year date includes the membership count" do
    date = Date.new(2024, 9, 16)
    count = Delivery.memberships_receiving_basket_count(date)
    assert count.positive?

    post deliveries_path, params: {
      delivery: {
        date: date.to_s,
        basket_size_price_percentage: -1
      }
    }

    assert_response :unprocessable_entity
    confirm = css_select("button[type=submit]").first["data-confirm"]
    assert_includes confirm, count.to_s
    assert_includes confirm, "weekday"
    assert_not_includes confirm, "special delivery"
  end

  test "bulk create confirm includes memberships that receive at least one basket" do
    delivery = Delivery.new(
      bulk_dates_starts_on: "2024-09-16",
      bulk_dates_ends_on: "2024-09-30",
      bulk_dates_weeks_frequency: 1,
      bulk_dates_wdays: [ 1 ])
    count = Delivery.memberships_receiving_basket_count_for(delivery.bulk_dates)
    assert count.positive?

    post deliveries_path, params: {
      delivery: {
        bulk_dates_starts_on: "2024-09-16",
        bulk_dates_ends_on: "2024-09-30",
        bulk_dates_weeks_frequency: 1,
        bulk_dates_wdays: [ 1 ],
        basket_size_price_percentage: -1
      }
    }

    assert_response :unprocessable_entity
    confirm = css_select("button[type=submit]").first["data-confirm"]
    assert_includes confirm, "at least one"
    assert_includes confirm, count.to_s
  end

  test "creates a unique date even when leftover bulk dates are submitted" do
    assert_difference -> { Delivery.count }, 1 do
      post deliveries_path, params: {
        delivery: {
          date: "2024-09-18",
          bulk_dates_starts_on: "2024-09-11",
          bulk_dates_wdays: [ 1 ]
        }
      }
    end

    delivery = Delivery.find_by!(date: "2024-09-18")
    assert_redirected_to delivery_path(delivery)
    assert_nil delivery.bulk_dates_starts_on
  end

  test "keeps unique date selected after another field is invalid" do
    assert_no_difference -> { Delivery.count } do
      post deliveries_path, params: {
        delivery: {
          date: "2024-09-18",
          bulk_dates_starts_on: "2024-09-11",
          basket_size_price_percentage: -1
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "a[aria-controls=unique_date][aria-selected=true]"
    assert_select "fieldset#unique_date:not([disabled])"
    assert_select "fieldset#bulk_dates[disabled]"
    assert_select "input#delivery_date[value='2024-09-18']"
  end

  test "show depot rows include a sortable grip" do
    travel_to "2024-04-01"
    login admins(:super)

    get delivery_path(deliveries(:monday_1))

    assert_response :success
    assert_select "tbody[data-controller='sortable'] .cluster.is-nowrap > .sortable-handle"
  end
end

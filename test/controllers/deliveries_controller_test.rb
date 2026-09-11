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
end

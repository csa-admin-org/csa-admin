# frozen_string_literal: true

require "test_helper"

class DeliveryCyclesControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-05-01"
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "edit shows the default form details placeholder" do
    login admins(:super)
    cycle = delivery_cycles(:mondays)

    get edit_delivery_cycle_path(cycle)

    assert_response :success
    assert_select "fieldset[data-controller='form-details-preview']"
    assert_select "input#delivery_cycle_form_detail_en[placeholder]"
  end

  test "form details preview follows live schedule not the cached count" do
    login admins(:super)

    get form_details_preview_delivery_cycles_path, params: {
      delivery_cycle: {
        price: 0,
        absences_included_annually: 0,
        wdays: [ 1, 4 ],
        periods_attributes: {
          "0" => { from_fy_month: 1, to_fy_month: 12, results: "all" }
        }
      }
    }

    assert_response :success
    assert_select "turbo-frame#delivery-cycle-form-details [data-placeholder-en*='20']"
    assert_select "turbo-frame#delivery-cycle-form-details [data-placeholder-en*='10']",
      count: 0
  end

  test "new shows a live deliveries placeholder not zero" do
    login admins(:super)

    get new_delivery_cycle_path

    assert_response :success
    assert_select "input#delivery_cycle_form_detail_en[placeholder*='20']"
  end

  test "edit shows the default invoice name placeholder" do
    login admins(:super)
    cycle = delivery_cycles(:mondays)

    get edit_delivery_cycle_path(cycle)

    assert_response :success
    assert_select "fieldset[data-controller='form-invoice-name']"
    assert_select "input#delivery_cycle_invoice_name_en[placeholder=?]",
      "#{Delivery.model_name.human(count: 2)}: #{cycle.public_name}"
  end
end

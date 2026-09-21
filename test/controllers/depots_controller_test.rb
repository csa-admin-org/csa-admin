# frozen_string_literal: true

require "test_helper"

class DepotsControllerTest < ActionDispatch::IntegrationTest
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
    depot = depots(:bakery)

    get edit_depot_path(depot)

    assert_response :success
    assert_select "fieldset[data-controller='form-details-preview']"
    assert_select "input#depot_form_detail_en[placeholder*='4']"
  end

  test "form details preview follows the form price and address" do
    login admins(:super)
    cycle = delivery_cycles(:mondays)

    get form_details_preview_depots_path, params: {
      depot: {
        price: 7,
        street: "1 Rue",
        zip: "1000",
        city: "Lausanne",
        delivery_cycle_ids: [ cycle.id ]
      }
    }

    assert_response :success
    assert_select "turbo-frame#depot-form-details [data-placeholder-en*='7']"
    assert_select "turbo-frame#depot-form-details [data-placeholder-en*='1 Rue']"
  end

  test "form details preview keeps empty cycle ids empty" do
    login admins(:super)

    get form_details_preview_depots_path, params: {
      depot: {
        price: 7,
        street: "1 Rue",
        zip: "1000",
        city: "Lausanne",
        delivery_cycle_ids: []
      }
    }

    assert_response :success
    assert_select "turbo-frame#depot-form-details [data-placeholder-en*='1 Rue']"
  end

  test "edit shows the default invoice name placeholder" do
    login admins(:super)
    depot = depots(:bakery)

    get edit_depot_path(depot)

    assert_response :success
    assert_select "fieldset[data-controller='form-invoice-name']"
    assert_select "input#depot_invoice_name_en[placeholder=?]",
      "#{Depot.model_name.human}: #{depot.public_name}"
  end

  test "home delivery show lists members with a sortable grip" do
    travel_to "2024-04-01"
    login admins(:super)

    get depot_path(depots(:home))

    assert_response :success
    assert_select "tbody[data-controller='sortable'] .sortable-handle"
  end
end

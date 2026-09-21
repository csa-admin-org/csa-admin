# frozen_string_literal: true

require "test_helper"

class BasketSizesControllerTest < ActionDispatch::IntegrationTest
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
    size = basket_sizes(:medium)

    get edit_basket_size_path(size)

    assert_response :success
    assert_select "fieldset[data-controller='form-details-preview']"
    assert_select "input#basket_size_form_detail_en[placeholder*='20']"
    assert_select "turbo-frame#basket-size-form-details [data-placeholder-en*='20']"
  end

  test "new shows a default form details placeholder" do
    login admins(:super)

    get new_basket_size_path

    assert_response :success
    assert_select "input#basket_size_form_detail_en[placeholder]"
  end

  test "form details preview follows the form price" do
    login admins(:super)

    get form_details_preview_basket_sizes_path, params: {
      basket_size: {
        price: 99,
        activity_participations_demanded_annually: 0
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-size-form-details [data-placeholder-en*='99']"
  end

  test "form details preview keeps a custom override out of the payload" do
    login admins(:super)
    size = basket_sizes(:medium)

    get form_details_preview_basket_sizes_path, params: {
      basket_size: {
        price: size.price,
        activity_participations_demanded_annually: size.activity_participations_demanded_annually,
        form_detail_en: "Custom copy"
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-size-form-details [data-placeholder-en*='20']"
    assert_select "turbo-frame#basket-size-form-details [data-placeholder-en=?]",
      "Custom copy",
      count: 0
  end
end

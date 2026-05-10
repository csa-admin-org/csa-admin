# frozen_string_literal: true

require "test_helper"

class BasketContentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
    login admins(:super)
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "form prices include baskets counts and total values" do
    get form_prices_basket_contents_path, params: {
      delivery_id: deliveries(:monday_1).id,
      product_id: basket_content_products(:carrots).id,
      unit: "kg",
      unit_price: "2",
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      }
    }

    assert_response :success
    assert_select "turbo-frame#basket-content-form-prices"
    assert_select "[data-baskets-count-for='#{small_id}'][data-baskets-count='1']"
    assert_select "[data-basket-size-id='#{small_id}'] [data-baskets-count-text]", /1x/
    assert_select "[data-basket-size-id='#{small_id}'] [data-total-value]"
    assert_select "[data-total-product-value]"
    assert_select "[data-total-quantity-surplus]", /Surplus: 750/
  end

  test "form prices renders zero surplus for exact rounded total" do
    get form_prices_basket_contents_path, params: {
      delivery_id: deliveries(:monday_1).id,
      product_id: basket_content_products(:carrots).id,
      unit: "kg",
      unit_price: "2",
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 500
      }
    }

    assert_response :success
    assert_select "[data-total-quantity-surplus]", /Surplus: 0/
  end

  test "form prices still returns basket counts without unit price" do
    get form_prices_basket_contents_path, params: {
      delivery_id: deliveries(:monday_1).id,
      depot_ids: [ depots(:home).id, depots(:farm).id ]
    }

    assert_response :success
    assert_select "[data-baskets-count-for='#{small_id}'][data-baskets-count='1']"
    assert_select "[data-total-product-value]", false
  end

  test "form prices renders surplus without unit price" do
    get form_prices_basket_contents_path, params: {
      delivery_id: deliveries(:monday_1).id,
      unit: "kg",
      depot_ids: [ depots(:home).id, depots(:farm).id ],
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      }
    }

    assert_response :success
    assert_select "[data-total-quantity-surplus]", /Surplus: 750/
    assert_select "[data-basket-size-id]", false
  end

  test "form prices returns zero basket counts when every depot is unchecked" do
    get form_prices_basket_contents_path, params: {
      delivery_id: deliveries(:monday_1).id,
      product_id: basket_content_products(:carrots).id,
      unit: "kg",
      unit_price: "2",
      depot_ids_empty: "1",
      basket_size_ids_quantities: {
        small_id => 500,
        medium_id => 750
      }
    }

    assert_response :success
    assert_select "[data-baskets-count-for='#{small_id}'][data-baskets-count='0']"
    assert_select "[data-baskets-count-for='#{medium_id}'][data-baskets-count='0']"
    assert_select "[data-total-quantity-surplus]", /Surplus: 0/
  end
end

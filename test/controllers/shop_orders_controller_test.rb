# frozen_string_literal: true

require "test_helper"

class ShopOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
    login admins(:super)
  end

  test "edit blanks item price that matches the variant default" do
    order = shop_orders(:john)
    item = shop_order_items(:john_bread_500)

    get edit_shop_order_path(order)

    assert_response :success
    price = css_select("input[name='shop_order[items_attributes][0][item_price]']").first
    assert price
    assert_equal "", price["value"].to_s
    assert_equal "5", price["placeholder"]
    assert_select "select[name='shop_order[items_attributes][0][product_variant_id]'] option[value='#{item.product_variant_id}'][data-price='5']"
  end

  test "edit keeps an item price override" do
    item = shop_order_items(:john_bread_500)
    item.update_column(:item_price, 6.5)

    get edit_shop_order_path(item.order)

    assert_response :success
    price = css_select("input[name='shop_order[items_attributes][0][item_price]']").first
    assert_equal "6.5", price["value"]
    assert_equal "5", price["placeholder"]
  end

  test "index disables delivery PDF until a delivery is filtered" do
    travel_to "2024-01-01"
    login admins(:super)

    get shop_orders_path

    assert_response :success
    assert_select "a[href*='#{delivery_shop_orders_path(format: :pdf)}']", false
    assert_select ".action-item-button.is-disabled"
    assert_select ".tooltip-body",
      text: I18n.t("active_admin.shared.action_items.delivery_orders_filter_required")
  end

  test "index enables delivery PDF when filtered by delivery" do
    travel_to "2024-01-01"
    login admins(:super)
    delivery = deliveries(:monday_1)

    get shop_orders_path, params: { q: { _delivery_gid_eq: delivery.gid } }

    assert_response :success
    assert_select "a.action-item-button[href*='.pdf']",
      text: I18n.t("active_admin.shared.action_items.delivery_orders")
    assert_select ".action-item-button.is-disabled",
      text: I18n.t("active_admin.shared.action_items.delivery_orders"), count: 0
  end

  private

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end

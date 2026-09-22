# frozen_string_literal: true

require "test_helper"

class ShopOrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    travel_to "2024-01-01"
    host! "admin.acme.test"
    login admins(:super)
  end

  test "new form searches members and pins recent shop members" do
    get new_shop_order_path

    assert_response :success
    select = css_select("select[name='shop_order[member_id]']").first
    assert_equal "searchable-select", select["data-controller"]
    assert_select select, "option[value='']"
    assert_select select, "optgroup[label=?]", I18n.t("active_admin.searchable_select.recent") do
      assert_select "option[value='#{members(:john).id}'][data-recent='true']"
    end
    assert_select select, "optgroup[label=?] option[value='#{members(:john).id}']",
      I18n.t("active_admin.searchable_select.all"), count: 0
    values = select.css("option[value]:not([value=''])").map { |option| option["value"] }
    assert_equal values.uniq, values
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
    assert_select "select[name='q[member_id_eq]'][data-controller='searchable-select']"
    assert_select "select[name='q[member_id_eq]'] optgroup", count: 0
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

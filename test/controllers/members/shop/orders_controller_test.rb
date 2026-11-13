# frozen_string_literal: true

require "test_helper"
require "open3"

class Members::Shop::OrdersControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "members.acme.test"
    travel_to "2024-04-01"
    login(members(:jane))
  end

  test "plus payload on a kilogram line adds one kilogram" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(unit: "kg", stock: 10)
    order = cart_with(variant, "0.66")

    patch members_shop_order_path(order), params: item_params(order, "1.66")

    assert_equal "1.66".to_d, order.reload.items.sole.quantity
  end

  test "minus payload of zero removes a half kilogram line" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(unit: "kg")
    order = cart_with(variant, "0.5")

    patch members_shop_order_path(order), params: item_params(order, "0")

    assert_empty order.reload.items
  end

  test "kilogram buttons snap a fractional quantity" do
    output, status = Open3.capture2e(
      { "NODE_OPTIONS" => "--disable-warning=MODULE_TYPELESS_PACKAGE_JSON" },
      "node", "--test",
      Rails.root.join("test/javascript/quantity_step.test.mjs").to_s)
    assert_equal 0, status.exitstatus, output
  end

  test "plus stays available when less than a kilogram remains" do
    variant = shop_product_variants(:flour_wheat)
    variant.update!(unit: "kg", stock: "11.02")
    order = cart_with(variant, "11")

    get members_shop_order_path(order)

    assert_response :success
    assert_select "button.shop-qty-btn.is-plus:not([disabled])"

    patch members_shop_order_path(order), params: item_params(order, "11.02")

    assert_equal "11.02".to_d, order.reload.items.sole.quantity
  end

  test "piece plus payload adds one and a half piece is rejected" do
    order = create_shop_order(state: "cart")

    patch members_shop_order_path(order), params: item_params(order, "2")
    assert_equal 2, order.reload.items.sole.quantity.to_d

    patch members_shop_order_path(order), params: item_params(order, "1.5")
    assert_response :unprocessable_entity
    assert_equal 2, order.reload.items.sole.quantity.to_d
  end

  private

  def cart_with(variant, quantity)
    create_shop_order(state: "cart", items_attributes: {
      "0" => {
        product_id: variant.product_id,
        product_variant_id: variant.id,
        quantity: quantity
      }
    })
  end

  def item_params(order, quantity)
    {
      shop_order: {
        items_attributes: {
          "0" => { id: order.items.sole.id, quantity: quantity }
        }
      }
    }
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end
end

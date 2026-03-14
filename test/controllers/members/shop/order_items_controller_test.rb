# frozen_string_literal: true

require "test_helper"

class Members::Shop::OrderItemsControllerTest < ActionDispatch::IntegrationTest
  include ShopHelper

  setup do
    host! "members.acme.test"
    travel_to "2024-04-01"
  end

  def login(member)
    session = Session.create!(
      member: member,
      email: member.emails_array.first,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "create renders turbo_stream with cart partial" do
    order = create_shop_order(member: members(:jane), state: "cart")

    login(members(:jane))

    assert_changes -> { order.reload.items.sum(:quantity) }, from: 1, to: 2 do
      post members_shop_order_order_items_path(order),
        params: { variant_id: shop_product_variants(:oil_500).id },
        headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_match "cart", response.body
  end
end

# frozen_string_literal: true

require "test_helper"

class AdminBatchActionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    host! "admin.acme.test"
  end

  def login(admin)
    session = Session.create!(
      admin_email: admin.email,
      remote_addr: "127.0.0.1",
      user_agent: "Test Browser")
    get "/sessions/#{session.generate_token_for(:redeem)}"
  end

  test "read-only admin cannot open shop on deliveries" do
    travel_to "2024-01-01"
    org(features: [ :shop ])
    delivery = deliveries(:monday_1)
    delivery.update_column(:shop_open, false)
    login admins(:external)

    post batch_action_deliveries_path, params: {
      batch_action: "open_shop",
      collection_selection: [ delivery.id ]
    }

    assert_denied_batch_action
    assert_not delivery.reload.shop_open?
  end

  test "delivery writer can open shop on deliveries" do
    travel_to "2024-01-01"
    org(features: [ :shop ])
    delivery = deliveries(:monday_1)
    delivery.update_column(:shop_open, false)
    login admins(:super)

    post batch_action_deliveries_path, params: {
      batch_action: "open_shop",
      collection_selection: [ delivery.id ]
    }

    assert_redirected_to deliveries_path
    assert delivery.reload.shop_open?
  end

  test "read-only admin cannot make a shop product available" do
    org(features: [ :shop ])
    product = shop_products(:oil)
    product.update_column(:available, false)
    login admins(:external)

    post batch_action_shop_products_path, params: {
      batch_action: "make_available",
      collection_selection: [ product.id ],
      scope: "unavailable"
    }

    assert_denied_batch_action
    assert_not product.reload.available?
  end

  test "shop writer can make a shop product available" do
    org(features: [ :shop ])
    admins(:external).permission.update!(rights: { shop: :write })
    product = shop_products(:oil)
    product.update_column(:available, false)
    login admins(:external)

    post batch_action_shop_products_path, params: {
      batch_action: "make_available",
      collection_selection: [ product.id ],
      scope: "unavailable"
    }

    assert product.reload.available?
  end

  test "read-only admin cannot invoice shop orders" do
    org(features: [ :shop ])
    order = shop_orders(:john)
    login admins(:external)

    assert_no_difference -> { Invoice.count } do
      post batch_action_shop_orders_path, params: {
        batch_action: "invoice",
        collection_selection: [ order.id ],
        scope: "pending"
      }
    end

    assert_denied_batch_action
    assert order.reload.pending?
  end

  test "shop writer can invoice shop orders" do
    travel_to "2024-04-01"
    org(features: [ :shop ])
    admins(:external).permission.update!(rights: { shop: :write })
    order = shop_orders(:john)
    login admins(:external)

    assert_difference -> { Invoice.count }, 1 do
      post batch_action_shop_orders_path, params: {
        batch_action: "invoice",
        collection_selection: [ order.id ],
        scope: "pending"
      }
    end

    assert_not order.reload.pending?
  end

  private

  def assert_denied_batch_action
    assert_response :redirect
    assert flash[:alert].present?
  end
end

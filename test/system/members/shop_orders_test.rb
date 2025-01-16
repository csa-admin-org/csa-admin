# frozen_string_literal: true

require "application_system_test_case"

class Members::ShopOrdersTest < ApplicationSystemTestCase
  setup do
    login(members(:jane))
  end

  test "increase order item with input" do
    travel_to "2024-04-01"
    shop_product_variants(:oil_500).update!(stock: 3)
    order = create_shop_order(state: "cart",
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          quantity: 2
        },
        "1" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_1000).id,
          quantity: 1
        }
      })

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    fill_in "shop_order_items_attributes_1_quantity", with: 4
    find('input[aria-label="update_order"]').click
    assert_text "must be less than or equal to 3"

    fill_in "shop_order_items_attributes_1_quantity", with: 3
    find('input[aria-label="update_order"]').click

    assert_equal [
      [ shop_product_variants(:oil_500).id, 3 ],
      [ shop_product_variants(:oil_1000).id, 1 ]
    ], order.reload.items.pluck(:product_variant_id, :quantity)
  end

  test "remove a cart order item" do
    travel_to "2024-04-01"
    order = create_shop_order(state: "cart",
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          quantity: 2
        },
        "1" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_1000).id,
          quantity: 1
        }
      })

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    fill_in "shop_order_items_attributes_0_quantity", with: 3
    fill_in "shop_order_items_attributes_1_quantity", with: 0
    find('input[aria-label="update_order"]', visible: false).click

    assert_equal [
      [ shop_product_variants(:oil_1000).id, 3 ]
    ], order.reload.items.pluck(:product_variant_id, :quantity)
  end

  test "unavailable product in cart order" do
    travel_to "2024-04-01"
    order = create_shop_order(state: "cart")
    shop_products(:oil).update!(available: false)

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    within 'label[for="shop_order_items_attributes_0_quantity"]' do
      assert_text "unavailable"
    end

    button = find('button[aria-label="confirm_order"]')
    assert button.disabled?
  end

  test "cart can be finalize depending date" do
    travel_to "2024-04-02 12:00:00"
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))
    order = create_shop_order(state: "cart")

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    assert_text "Your order can be placed or modified until Tuesday 2 April 2024, 12:00."
    assert_button "Order"

    travel_to "2024-04-02 12:00:01"
    visit "/shop/orders/#{order.id}"
    assert_equal "/shop", current_path
    assert_text "It is no longer possible to place an order for this delivery."
  end

  test "add a percentage to the pending order" do
    travel_to "2024-04-01"
    org(shop_member_percentages: [ 5, 10, 20 ])
    order = create_shop_order(state: "cart")

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    assert_text "TotalCHF 6.00"

    select "Support +10%"
    find('input[aria-label="update_order"]').click

    assert_text "TotalCHF 6.60"
  end

  test "pending order can be modified/deleted depending date" do
    travel_to "2024-04-02 12:00:00"
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))
    order = create_shop_order

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path
    assert_text "Your order has been received but can still be canceled or modified until Tuesday 2 April 2024, 12:00"
    assert_button "Edit"
    assert_button "Cancel order"

    travel_to "2024-04-02 12:00:01"
    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path
    assert_text "Your order is being prepared. An invoice will be sent to you shortly by email."
    assert_no_button "Edit"
    assert_no_button "Cancel order"
  end

  test "invoiced order" do
    enable_invoice_pdf
    travel_to "2024-04-01"
    org(
      shop_delivery_open_delay_in_days: 2,
      shop_delivery_open_last_day_end_time: Tod::TimeOfDay.parse("12:00:00"))
    order = create_shop_order
    perform_enqueued_jobs do
      order.invoice!
    end

    visit "/shop/orders/#{order.id}"
    assert_equal "/shop/orders/#{order.id}", current_path

    assert_text "Your order is ready, the invoice has been sent to you by email."
    assert_link "Invoice ##{order.invoice.id}"
    assert_text "Have a question? Feel free to contact us"
  end
end

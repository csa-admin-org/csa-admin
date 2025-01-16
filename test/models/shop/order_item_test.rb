# frozen_string_literal: true

require "test_helper"

class Shop::OrderItemTest < ActiveSupport::TestCase
  test "set product variant price by default" do
    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        item_price: "",
        quantity: 2
      },
      "1" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_500).id,
        item_price: "5.5",
        quantity: 3
      }
    })

    assert_equal 2 * 5 + 3 * 5.5, order.amount
    first_item = order.items.first
    assert_equal 5, first_item.item_price
    assert_equal 2, first_item.quantity
    assert_equal 2 * 5, first_item.amount
    last_item = order.items.last
    assert_equal 5.5, last_item.item_price
    assert_equal 3, last_item.quantity
    assert_equal 3 * 5.5, last_item.amount
  end

  test "validate available stock on creation (pending)" do
    shop_product_variants(:bread_500).update!(stock: 2)

    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 3
      }
    })

    order.validate
    assert_includes order.items.first.errors[:quantity], "must be less than or equal to 2"
  end

  test "validate and update stock on update (pending)" do
    product = shop_products(:bread)
    shop_product_variants(:bread_500).update!(stock: 2)

    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 1
      }
    })

    assert_equal 1, product.variants.first.reload.stock

    order.update(items_attributes: {
      "0" => {
        id: order.items.first.id,
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 3
      }
    })

    assert_includes order.items.first.errors[:quantity], "must be less than or equal to 2"

    order.update!(items_attributes: {
      "0" => {
        id: order.items.first.id,
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 2
      }
    })

    assert_equal 0, product.variants.first.reload.stock
  end

  test "validate product is available for delivery" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_1)
    delivery.update!(basket_complements: [])
    product = shop_products(:bread)
    product.update!(basket_complement_id: bread_id)

    order = build_shop_order(
      delivery: delivery,
      items_attributes: {
        "0" => {
          product_id: shop_products(:bread).id,
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 1
        }
      })

    order.validate
    assert_includes order.items.first.errors[:product], "Not available for this delivery"
  end

  test "releases stock when deleting order (pending)" do
    product = shop_products(:bread)
    shop_product_variants(:bread_500).update!(stock: 3)

    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 2
      }
    })

    assert_equal 1, product.variants.first.reload.stock
    assert_difference -> { product.variants.first.reload.stock }, 2 do
      order.destroy!
    end
  end
end

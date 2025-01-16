# frozen_string_literal: true

require "test_helper"

class Shop::OrderTest < ActiveSupport::TestCase
  test "validate maximum weight when defined" do
    org(shop_order_maximum_weight_in_kg: 10)
    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 100
      },
      "1" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_500).id,
        quantity: 3
      }
    })

    assert_not order.valid?
    assert_equal 51.5, order.weight_in_kg
    assert_includes order.errors.messages[:base],
      "The total weight of the order cannot exceed 10.0 kg"
  end

  test "is valid when equal to the maximum weight limit" do
    org(shop_order_maximum_weight_in_kg: 10)
    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_1000).id,
        quantity: 10
      }
    })

    assert order.valid?
  end

  test "skip validation when maximum weight is not defined" do
    org(shop_order_maximum_weight_in_kg: nil)
    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_500).id,
        quantity: 5
      },
      "1" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_1000).id,
        quantity: 10
      }
    })

    assert order.valid?
  end

  test "skip maximum_weight_limit validation when edited by admin" do
    org(shop_order_maximum_weight_in_kg: 10)
    order = build_shop_order(items_attributes: {
      "1" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_1000).id,
        quantity: 11
      }
    })
    order.admin = members(:john)

    assert order.valid?
    assert_equal 11, order.weight_in_kg
  end

  test "validate minimum order amount when defined" do
    org(shop_order_minimal_amount: 20)
    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        item_price: 5,
        quantity: 1
      },
      "1" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_500).id,
        item_price: 6,
        quantity: 1
      }
    })

    assert_not order.valid?
    assert_equal 11, order.amount
    assert_includes order.errors.messages[:base], "The minimum order amount is CHF 20.00"
  end

  test "is valid when equal to the minimal amount" do
    org(shop_order_minimal_amount: 20)
    order = build_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        item_price: 5,
        quantity: 4
      }
    })

    assert order.valid?
  end

  test "skip minimal_amount validation when minimal amount is not defined" do
    org(shop_order_minimal_amount: nil)
    order = build_shop_order(items_attributes: {
      "1" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        item_price: 5,
        quantity: 1
      }
    })

    assert order.valid?
  end

  test "skip minimal_amount validation when edited by admin" do
    org(shop_order_minimal_amount: 20)
    order = build_shop_order(items_attributes: {
      "1" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        item_price: 5,
        quantity: 3
      }
    })
    order.admin = admins(:master)

    assert order.valid?
    assert_equal 15, order.amount
  end

  test "support polymorphic delivery association" do
    delivery = deliveries(:monday_1)
    order = create_shop_order(delivery_gid: delivery.gid)
    special_delivery = shop_special_deliveries(:wednesday)
    special_order = create_shop_order(delivery_gid: special_delivery.gid)

    assert_equal "gid://csa-admin/Delivery/#{delivery.id}", order.delivery_gid
    assert_equal "gid://csa-admin/Shop::SpecialDelivery/#{special_delivery.id}", special_order.delivery_gid

    assert_equal [ order ], Shop::Order._delivery_gid_eq(delivery.gid)
    assert_equal [ special_order ], Shop::Order._delivery_gid_eq(special_delivery.gid)
  end

  test "update amount when removing item" do
    product = shop_products(:oil)
    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        item_price: 10,
        quantity: 2
      }
    })

    assert_difference -> { order.reload.amount }, -20 do
      order.update!(items_attributes: {
        "0" => {
          id: order.items.first.id,
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        },
        "1" => {
          id: order.items.last.id,
          _destroy: true
        }
      })
    end
  end

  test "change state to pending and decrement product stock" do
    product = shop_products(:oil)
    order = create_shop_order(state: "cart", items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        quantity: 2
      }
    })

    assert_changes -> { product.variants.first.reload.stock }, -1 do
      assert_changes -> { product.variants.second.reload.stock }, -2 do
        assert_changes -> { order.reload.state }, from: "cart", to: "pending" do
          order.confirm!
        end
      end
    end
  end

  test "persist the depot" do
    travel_to "2024-01-01"
    member = members(:jane)
    depot = member.current_membership.depot
    order = create_shop_order(state: "cart", member: member)
    perform_enqueued_jobs

    assert_equal depot, order.depot

    assert_changes -> { order.reload.depot_id }, from: nil, to: depot.id do
      order.confirm!
    end
  end

  test "update product stock when pending order is changing" do
    travel_to "2024-01-01"
    product = shop_products(:oil)
    order = create_shop_order(state: "cart", items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        quantity: 2
      }
    })
    order.confirm!
    order.reload

    assert_changes -> { product.variants.first.reload.stock }, -1 do
      assert_changes -> { product.variants.second.reload.stock }, 1 do
        order.update!(items_attributes: {
          "0" => {
            id: order.items.first.id,
            quantity: 2
          },
          "1" => {
            id: order.items.second.id,
            quantity: 1
          }
        })
      end
    end

    assert_equal 2, order.items.size
  end

  test "change state to pending and increment product stock" do
    travel_to "2024-01-01"
    product = shop_products(:oil)
    order = create_shop_order(state: "cart", items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        quantity: 4
      }
    })
    order.confirm!
    order.reload

    assert_changes -> { product.variants.first.reload.stock }, 1 do
      assert_changes -> { product.variants.second.reload.stock }, 4 do
        assert_changes -> { order.reload.state }, from: "pending", to: "cart" do
          order.unconfirm!
        end
      end
    end
  end

  test "set percentage (reduction)" do
    travel_to "2024-01-01"
    product = shop_products(:oil)
    order = create_shop_order(state: "cart",
      amount_percentage: -15.5,
      items_attributes: {
        "0" => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          item_price: 10,
          quantity: 1
        }
      })

    assert_equal 10, order.amount_before_percentage
    assert_equal -15.5, order.amount_percentage
    assert_equal 8.45, order.amount
  end

  test "set percentage (increase)" do
    travel_to "2024-01-01"
    product = shop_products(:oil)
    order = create_shop_order(state: "cart",
      amount_percentage: 21.5,
      items_attributes: {
        "0" => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          item_price: 10,
          quantity: 1
        }
      })

    assert_equal 10, order.amount_before_percentage
    assert_equal 21.5, order.amount_percentage
    assert_equal 12.15, order.amount
  end

  test "auto invoice after delivery date" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)
    order = create_shop_order(delivery_gid: delivery.gid)
    org(shop_order_automatic_invoicing_delay_in_days: 3)

    travel_to "2024-04-03"
    assert_no_changes -> { order.reload.state } do
      order.auto_invoice!
    end

    travel_to "2024-04-04"
    assert_changes -> { order.reload.state }, from: "pending", to: "invoiced" do
      order.auto_invoice!
    end
  end

  test "auto invoice before delivery date" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)
    order = create_shop_order(delivery_gid: delivery.gid)
    org(shop_order_automatic_invoicing_delay_in_days: -2)

    travel_to "2024-03-29"
    assert_no_changes -> { order.reload.state } do
      order.auto_invoice!
    end

    travel_to "2024-03-30"
    assert_changes -> { order.reload.state }, from: "pending", to: "invoiced" do
      order.auto_invoice!
    end
  end

  test "auto invoice the delivery date" do
    delivery = deliveries(:monday_1)
    order = create_shop_order(delivery_gid: delivery.gid)
    org(shop_order_automatic_invoicing_delay_in_days: 0)

    travel_to delivery.date
    assert_changes -> { order.reload.state }, from: "pending", to: "invoiced" do
      order.auto_invoice!
    end
  end

  test "do nothing when no delay configured" do
    delivery = deliveries(:monday_1)
    order = create_shop_order(delivery_gid: delivery.gid)
    org(shop_order_automatic_invoicing_delay_in_days: nil)

    travel_to "2024-05-01"
    assert_no_changes -> { order.reload.state } do
      order.auto_invoice!
    end
  end

  test "do nothing for cart order" do
    travel_to "2024-05-01"
    org(shop_order_automatic_invoicing_delay_in_days: 0)
    order = create_shop_order(state: "cart")

    assert_no_changes -> { order.reload.state } do
      order.auto_invoice!
    end
  end

  test "do nothing for invoiced order" do
    travel_to "2024-05-01"
    org(shop_order_automatic_invoicing_delay_in_days: 0)
    order = create_shop_order(state: "invoiced")

    assert_no_changes -> { order.reload.state } do
      order.auto_invoice!
    end
  end

  test "create an invoice and set state to invoiced" do
    travel_to "2024-04-03 12:42:42 +02"
    product = shop_products(:oil)
    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        item_price: 16.00,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        item_price: 29.55,
        quantity: 2
      }
    })

    assert_changes -> { order.reload.state }, from: "pending", to: "invoiced" do
      assert_difference -> { Invoice.count }, 1 do
        order.invoice!
        perform_enqueued_jobs
      end
    end

    assert_equal order.id, order.invoice.entity_id
    assert_equal "Shop::Order", order.invoice.entity_type
    assert_equal BigDecimal(16 + 2 * 29.55, 3), order.invoice.amount
    assert_equal Date.new(2024, 4, 3), order.invoice.date
    assert_equal Time.zone.parse("2024-04-03 12:42:42 +02"), order.invoice.sent_at

    assert_equal 16, order.invoice.items.first.amount
    assert_equal "Oil, Olive 500ml, 1x 16.00", order.invoice.items.first.description
    assert_equal BigDecimal(2 * 29.55, 3), order.invoice.items.last.amount
    assert_equal "Oil, Olive 1l, 2x 29.55", order.invoice.items.last.description
  end

  test "cancel the invoice and set state back to pending" do
    travel_to "2024-01-01"
    order = create_shop_order
    invoice = order.invoice!
    perform_enqueued_jobs

    assert_changes -> { order.reload.state }, from: "invoiced", to: "pending" do
      assert_changes -> { invoice.reload.state }, from: "open", to: "canceled" do
        order.cancel!
      end
    end
    assert_nil order.invoice
  end

  test "allow invoice with negative amount" do
    travel_to "2024-01-01"
    product = shop_products(:oil)
    order = create_shop_order(items_attributes: {
      "0" => {
        product_id: product.id,
        product_variant_id: product.variants.first.id,
        item_price: 4,
        quantity: 1
      },
      "1" => {
        product_id: product.id,
        product_variant_id: product.variants.second.id,
        item_price: -5,
        quantity: 1
      }
    })

    assert_equal -1, order.amount
  end
end

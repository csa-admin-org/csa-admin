# frozen_string_literal: true

require "test_helper"

class Shop::ProductTest < ActiveSupport::TestCase
  test "supports variants linked to different basket complements" do
    product = shop_products(:oil)

    assert product.update(
      variants_attributes: {
        "0" => {
          id: shop_product_variants(:oil_500).id,
          basket_complement_id: basket_complements(:eggs).id
        },
        "1" => {
          id: shop_product_variants(:oil_1000).id,
          basket_complement_id: basket_complements(:cheese).id
        }
      })
    assert_equal [ basket_complements(:eggs), basket_complements(:cheese) ].sort,
      product.variants.map(&:basket_complement).sort
  end

  test "validate at least one available variant" do
    product = shop_products(:bread)
    product.update(variants_attributes: {
      "0" => {
        id: product.variants.first.id,
        available: false
      }
    })

    assert_not product.valid?
    assert_includes product.errors.messages[:base], "At least one variant must be available"
    assert product.variants.available.present?
  end

  test "validate only one variant when displayed in delivery sheets" do
    product = Shop::Product.new(
      display_in_delivery_sheets: true,
      variants_attributes: {
        "0" => {
          name: "100g",
          price: 5
        },
        "1" => {
          name: "200g",
          price: 10
        }
      })

    assert_not product.valid?
    assert_includes product.errors.messages[:display_in_delivery_sheets], "Cannot be activated if the product has multiple variants"
  end

  test "returns products that are available" do
    travel_to "2024-01-01"
    shop_products(:oil).update(available: false)

    assert_equal [ shop_products(:flour) ],
      Shop::Product.available_for(deliveries(:monday_1))
    assert_equal [ shop_products(:bread), shop_products(:flour) ].sort,
      Shop::Product.available_for(deliveries(:thursday_1)).sort
  end

  test "returns a product when one of its complement variants is available" do
    travel_to "2024-01-01"
    monday = deliveries(:monday_1)
    thursday = deliveries(:thursday_1)
    eggs = basket_complements(:eggs)
    cheese = basket_complements(:cheese)
    eggs.update!(delivery_ids: [ monday.id ])
    cheese.update!(delivery_ids: [ thursday.id ])
    shop_product_variants(:oil_500).update!(basket_complement: eggs)
    shop_product_variants(:oil_1000).update!(basket_complement: cheese)

    assert_includes Shop::Product.available_for(monday), shop_products(:oil)
    assert_includes Shop::Product.available_for(thursday), shop_products(:oil)
    assert_equal [ shop_product_variants(:oil_500) ], Shop::ProductVariant.available_for(monday)
      .where(product: shop_products(:oil))
    assert_equal [ shop_product_variants(:oil_1000) ], Shop::ProductVariant.available_for(thursday)
      .where(product: shop_products(:oil))
  end

  test "returns products that are available for the given depot" do
    travel_to "2024-01-01"
    shop_products(:oil).update(available_for_depot_ids: [ farm_id ])

    assert_equal [ shop_products(:flour), shop_products(:oil) ].sort,
      Shop::Product.available_for(deliveries(:monday_1), depots(:farm)).sort
    assert_equal [ shop_products(:flour) ],
      Shop::Product.available_for(deliveries(:monday_1), depots(:home))
  end

  test "returns products that are available for the given delivery" do
    travel_to "2024-01-01"
    shop_products(:oil).update(available_for_delivery_ids: [ deliveries(:monday_1).id ])

    assert_equal [ shop_products(:flour), shop_products(:oil) ].sort,
      Shop::Product.available_for(deliveries(:monday_1)).sort
    assert_equal [ shop_products(:flour) ],
      Shop::Product.available_for(deliveries(:monday_2))
  end

  test "ignore discarded products" do
    shop_products(:oil).discard

    assert_equal [ shop_products(:flour) ], Shop::Product.available_for(deliveries(:monday_1))
  end

  test "null producer" do
    product = shop_products(:bread)
    product.update(producer: nil)
    assert_equal Shop::NullProducer.instance, product.producer
  end

  test "#display_in_delivery_sheets" do
    product = Shop::Product.new(
      display_in_delivery_sheets: false,
      variants: [ Shop::ProductVariant.new(basket_complement: basket_complements(:bread)) ])
    assert product.display_in_delivery_sheets
    assert product.display_in_delivery_sheets

    product = Shop::Product.new(display_in_delivery_sheets: false)
    refute product.display_in_delivery_sheets
    assert_not product.display_in_delivery_sheets

    product.display_in_delivery_sheets = true
    assert product.display_in_delivery_sheets
    assert product.display_in_delivery_sheets
  end

  test "discard variants when product is destroyed/discarded" do
    product = shop_products(:oil)
    create_shop_order(
      state: "invoiced",
      items_attributes: {
        "0" => {
          product_id: product.id,
          product_variant_id: product.variants.first.id,
          quantity: 1
        }
      })

    assert_changes -> { product.reload.discarded_at }, from: nil do
      product.destroy
    end
    assert_not product.reload.destroyed?
    assert product.reload.discarded?
    assert_equal 2, product.all_variants.discarded.count
  end
end

# frozen_string_literal: true

require "test_helper"

class PDF::DeliveryTest < ActiveSupport::TestCase
  def save_pdf_and_return_strings(delivery)
    pdf = PDF::Delivery.new(delivery)
    # pdf.render_file(Rails.root.join("tmp/delivery.pdf"))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  test "generates invoice with support amount + complements + annual membership" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)
    delivery.update!(basket_complements: [
      basket_complements(:cheese),
      basket_complements(:eggs)
    ])
    members(:bob).update!(delivery_note: "Code 1234")
    memberships(:bob).baskets.first.update!(
      baskets_basket_complements_attributes: {
        "0" => { basket_complement_id: cheese_id, quantity: 1 },
        "1" => { basket_complement_id: eggs_id, quantity: 2 }
      })
    create_absence(
      member: members(:anna),
      started_on: delivery.date,
      ended_on: delivery.date + 1.week)

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_includes pdf_strings, "1 April 2024"

    assert_includes pdf_strings, "Our farm"
    assert_includes pdf_strings, "Medium basket"
    assert_includes pdf_strings, "Signature"
    assert_includes pdf_strings, "John Doe"
    assert_includes pdf_strings, "1"

    assert_includes pdf_strings, "Home"
    assert_includes pdf_strings, "Address"
    assert_includes pdf_strings, "Small basket"
    assert_includes pdf_strings, "Cheese"
    assert_includes pdf_strings, "Eggs"
    assert_includes pdf_strings, "Note"
    assert_includes pdf_strings, "Bob Doe"
    assert_includes pdf_strings, "Nowhere 44"
    assert_includes pdf_strings, "Code 1234"

    assert_includes pdf_strings, "Bakery"
    assert_includes pdf_strings, "Large basket"
    assert_includes pdf_strings, "Anna Doe"
    assert_includes pdf_strings, "1"
    assert_includes pdf_strings, "ABSENT"

    assert_includes pdf_strings, "If you have any comments or issues, please contact us at +41 76 449 59 38."
    assert_includes pdf_strings, "– 1 Jan 24, 00:00 –"

    assert_not pdf_strings.include?("Jane Doe")
  end

  test "includes announcement" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    Announcement.create!(
      text: "Bring back the bags!",
      depot_ids: [ farm_id ],
      delivery_ids: [ delivery.id ]
    )

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_includes pdf_strings, "Our farm"
    assert_includes pdf_strings, "Bring back the bags!"
  end

  test "includes shop orders" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_1)
    delivery.update!(shop_open: true)

    create_shop_order(
      member: members(:jane),
      delivery: delivery,
      depot: depots(:bakery),
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_1000).id,
          quantity: 2
        },
        "1" => {
          product_id: shop_products(:bread).id,
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 3
        }
      })

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_includes pdf_strings, "Bakery"
    assert_includes pdf_strings, "4 April 2024"
    assert_includes pdf_strings, "Large basket"
    assert_includes pdf_strings, "1"
    assert_includes pdf_strings, "Bread"
    assert_includes pdf_strings, "4"
    assert_includes pdf_strings, "Farm shop order"
    assert_includes pdf_strings, "1"
    assert_includes pdf_strings, "Signature"
    assert_includes pdf_strings, "Jane Doe"
  end
end

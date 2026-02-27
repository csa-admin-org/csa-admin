# frozen_string_literal: true

require "test_helper"

class PDF::DeliveryTest < ActiveSupport::TestCase
  def save_pdf_and_return_strings(delivery, depot = nil)
    pdf = PDF::Delivery.new(delivery, depot)
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
    assert_contains pdf_strings, "Member", "1", "Signature"
    assert_contains pdf_strings, "John Doe", "1"

    assert_includes pdf_strings, "Home"
    assert_contains pdf_strings, "Small basket", "Cheese", "Eggs"
    assert_contains pdf_strings, "1", "1", "2"
    assert_contains pdf_strings, "Member", "Address"
    assert_contains pdf_strings, "Bob Doe", "Nowhere 44", "1234 City"
    assert_includes pdf_strings, "Code 1234"

    assert_includes pdf_strings, "Bakery"
    assert_includes pdf_strings, "Large basket"
    assert_contains pdf_strings, "Anna Doe", "1", "ABSENT"

    assert_includes pdf_strings, "If you have any comments or issues, please contact us at +41 76 449 59 38."
    assert_includes pdf_strings, "– 1 Jan 24, 00:00 –"

    assert_not pdf_strings.include?("Jane Doe")
  end

  test "changes page shows ended members on monday_2" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2) # 2024-04-08, Bob & Anna ended 2024-04-05

    pdf_strings = save_pdf_and_return_strings(delivery)

    # Changes page header
    assert_includes pdf_strings, "Changes"

    # Bob and Anna should appear as ended with basket description
    assert pdf_strings.any? { |s| s.start_with?("Ended (") }, "Expected an 'Ended (...)' entry in PDF"
    assert_contains pdf_strings, "Bob Doe"
    assert_contains pdf_strings, "Anna Doe"
  end

  test "changes page on first delivery of fiscal year shows new members" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1) # first delivery of FY

    pdf_strings = save_pdf_and_return_strings(delivery)

    assert_includes pdf_strings, "Changes"
    assert_includes pdf_strings, "New"
  end

  test "changes page excluded from per-depot PDF" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    pdf_strings = save_pdf_and_return_strings(delivery, depots(:farm))

    assert_not_includes pdf_strings, "Changes"
  end

  test "changes page shows depot change" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_2)

    baskets(:john_2).update_columns(depot_id: depots(:bakery).id)

    pdf_strings = save_pdf_and_return_strings(delivery)

    assert_includes pdf_strings, "Changes"

    detail = pdf_strings.find { |s| s.include?("Farm") && s.include?("=>") && s.include?("Bakery") }
    assert detail, "Expected depot change details 'Farm => Bakery' in PDF"
  end

  test "changes page does not show ended members on later deliveries" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_5) # 2024-04-29, well after Bob/Anna ended on 2024-04-05

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_not_includes pdf_strings, "Ended"
  end

  test "no changes page when there are no changes" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_5)

    memberships(:bob).baskets.destroy_all
    memberships(:bob).destroy
    memberships(:anna).baskets.destroy_all
    memberships(:anna).destroy

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_not_includes pdf_strings, "Changes"
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
    assert_contains pdf_strings, "Large basket", "Bread", "Farm shop order"
    assert_contains pdf_strings, "1", "4", "1"
    assert_includes pdf_strings, "Signature"
    assert_includes pdf_strings, "Jane Doe"
  end
end

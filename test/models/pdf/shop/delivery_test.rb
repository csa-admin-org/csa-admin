# frozen_string_literal: true

require "test_helper"
require "tempfile"

class PDF::Shop::DeliveryTest < ActiveSupport::TestCase
  def save_pdf_and_return_strings(delivery, order: nil)
    pdf = PDF::Shop::Delivery.new(delivery, order: order)
    # pdf.render_file(Rails.root.join("tmp/shop-delivery.pdf"))
    PDF::Inspector::Text.analyze(pdf.render).strings
  end

  test "generates delivery notes for all orders" do
    delivery = deliveries(:thursday_1)
    create_shop_order(items_attributes: {
      "0" => {
        product_id: shop_products(:oil).id,
        product_variant_id: shop_product_variants(:oil_1000).id,
        quantity: 1
      },
      "1" => {
        product_id: shop_products(:bread).id,
        product_variant_id: shop_product_variants(:bread_500).id,
        quantity: 2
      }
    })

    pdf_strings = save_pdf_and_return_strings(delivery)
    assert_includes pdf_strings, "Jane Doe"
    assert_includes pdf_strings, "Bakery"
    assert_includes pdf_strings, "4 April 2024"
    assert_includes pdf_strings, "Delivery note"
    assert_contains pdf_strings, "Quantity", "Product"
    assert_contains pdf_strings, "2", "Bread, 500g, Farm"
    assert_contains pdf_strings, "1", "Oil, Olive 1l"
    assert_includes pdf_strings, "Invoice sent separately by email."
  end

  test "generates delivery for a specific order with multiple pages" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_1)

    product = shop_products(:oil)
    product.update(variants_attributes: 27.times.map { |i|
      [ i.to_s, { name: "Variant #{i}", price: i } ]
    }.to_h)
    variants = product.variants.to_a

    order = create_shop_order(items_attributes: 27.times.map { |i|
      [
        i.to_s,
        { product_id: product.id, product_variant_id: variants[i].id, quantity: 1 }
      ]
    }.to_h)

    pdf_strings = save_pdf_and_return_strings(delivery, order: order)
    assert_includes pdf_strings, "Jane Doe"
    assert_includes pdf_strings, "Bakery"
    assert_includes pdf_strings, "4 April 2024"
    assert_includes pdf_strings, "1 / 2"
    assert_includes pdf_strings, "2 / 2"
  end

  test "generates delivery notes for special delivery with depot" do
    special_delivery = shop_special_deliveries(:wednesday)
    create_shop_order(
      delivery: special_delivery,
      items_attributes: {
        "0" => {
          product_id: shop_products(:oil).id,
          product_variant_id: shop_product_variants(:oil_500).id,
          quantity: 1
        }
      })

    pdf_strings = save_pdf_and_return_strings(special_delivery)
    assert_includes pdf_strings, "Jane Doe"
    assert_includes pdf_strings, "5 April 2024"
    assert_includes pdf_strings, "Bakery"
  end

  test "filters by depot, caches org logo once across pages, and writes PDF to file" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_1)

    product = shop_products(:oil)
    product.update(variants_attributes: 27.times.map { |i|
      [ i.to_s, { name: "Variant #{i}", price: i } ]
    }.to_h)
    variants = product.variants.to_a

    order = create_shop_order(
      depot: depots(:bakery),
      items_attributes: 27.times.map { |i|
        [
          i.to_s,
          { product_id: product.id, product_variant_id: variants[i].id, quantity: 1 }
        ]
      }.to_h)
    create_shop_order(
      member: members(:john),
      depot: depots(:farm))

    pdf = PDF::Shop::Delivery.new(delivery, depot: depots(:bakery))
    logo_encode_calls = 0
    original_bytes_data_uri = pdf.method(:bytes_data_uri)
    pdf.define_singleton_method(:bytes_data_uri) do |*args, **kwargs|
      logo_encode_calls += 1
      original_bytes_data_uri.call(*args, **kwargs)
    end

    assert_equal "application/pdf", pdf.content_type
    assert_equal "farm-shop-delivery-#2-20240404.pdf", pdf.filename
    assert_equal delivery, pdf.delivery

    Tempfile.create([ "shop_delivery", ".pdf" ]) do |file|
      pdf.render_file(file.path)
      bytes = File.binread(file.path)
      assert bytes.start_with?("%PDF-")
      assert_equal 2, PDF::Inspector::Page.analyze(bytes).pages.size
      text = PDF::Inspector::Text.analyze(bytes).strings.join("\n")
      assert_includes text, order.member.name
      assert_not_includes text, members(:john).name
    end

    assert_equal 1, logo_encode_calls
  end
end

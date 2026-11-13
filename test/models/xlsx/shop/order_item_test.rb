# frozen_string_literal: true

require "test_helper"
require "rubyXL"
require "stringio"

class XLSX::Shop::OrderItemTest < ActiveSupport::TestCase
  test "writes price and amount as currency numbers" do
    travel_to "2024-01-01"
    order = create_shop_order(
      member: members(:jane),
      delivery: deliveries(:thursday_1),
      items_attributes: {
        "0" => {
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 3
        }
      })
    item = order.items.first
    workbook = RubyXL::Parser.parse_buffer(StringIO.new(XLSX::Shop::OrderItem.new(Shop::Order.where(id: order.id)).data))
    sheet = workbook.worksheets.first
    header = sheet[0].cells.map(&:value)
    price = header.index(Shop::OrderItem.human_attribute_name(:price))
    amount = header.index(Shop::OrderItem.human_attribute_name(:amount))
    quantity = header.index(Shop::OrderItem.human_attribute_name(:quantity))

    assert_equal item.item_price.to_f, sheet[1][price].value
    assert_equal item.amount.to_f, sheet[1][amount].value
    assert_equal 3, sheet[1][quantity].value
    assert_nil sheet[1][price].datatype
    assert_equal "[$CHF] #,##0.00;[$CHF] -#,##0.00", sheet[1][amount].number_format.format_code
    assert_equal "0.##", sheet[1][quantity].number_format.format_code
  end
end

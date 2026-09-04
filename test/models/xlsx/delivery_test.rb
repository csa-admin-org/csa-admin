# frozen_string_literal: true

require "test_helper"
require "rubyXL"
require "stringio"

class XLSX::DeliveryTest < ActiveSupport::TestCase
  def summary_rows_for(delivery)
    workbook = RubyXL::Parser.parse_buffer(StringIO.new(XLSX::Delivery.new(delivery).data))
    summary_sheet = workbook.worksheets.find { |sheet| sheet.sheet_name == I18n.t("delivery.summary") }

    summary_sheet.sheet_data.rows.compact.map do |row|
      row.cells.map { |cell| cell&.value }
    end
  end

  test "summary adds shop variant quantities to basket complements" do
    travel_to "2024-01-01"
    delivery = deliveries(:thursday_1)
    create_shop_order(
      member: members(:jane),
      delivery: delivery,
      depot: depots(:bakery),
      items_attributes: {
        "0" => {
          product_variant_id: shop_product_variants(:bread_500).id,
          quantity: 3
        }
      })

    rows = summary_rows_for(delivery)
    bread_column = rows.first.index(basket_complements(:bread).name)
    total_row = rows.reverse.find { |row| row.first == I18n.t("delivery.total") }
    expected = delivery.baskets.active.complement_count(basket_complements(:bread)) + 3

    assert_equal expected, total_row[bread_column]
  end

  test "summary includes depot-group and price sections when they partition depots differently" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    countryside = DepotGroup.create!(
      names: { en: "Countryside" },
      public_names: { en: "Countryside" },
      member_order_priority: 2)
    city = DepotGroup.create!(
      names: { en: "City" },
      public_names: { en: "City" },
      member_order_priority: 1)

    depots(:farm).update!(group: countryside)
    depots(:home).update!(group: countryside)
    depots(:bakery).update!(group: city)

    rows = summary_rows_for(delivery)

    city_row = rows.find { |row| row[0] == "City" }
    countryside_row = rows.find { |row| row[0] == "Countryside" }
    free_row = rows.find { |row| row[0] == I18n.t("delivery.free_depots") }
    paid_row = rows.find { |row| row[0] == I18n.t("delivery.paid_depots") }

    assert city_row, "Expected a City subtotal row in the summary worksheet"
    assert countryside_row, "Expected a Countryside subtotal row in the summary worksheet"
    assert free_row, "Expected a free depots subtotal row in the summary worksheet"
    assert paid_row, "Expected a paid depots subtotal row in the summary worksheet"

    assert_equal 1, city_row[1].to_i
    assert_equal 2, countryside_row[1].to_i
    assert_equal 1, free_row[1].to_i
    assert_equal 2, paid_row[1].to_i
  end

  test "summary includes ungrouped depot subtotals when grouped and ungrouped depots coexist" do
    travel_to "2024-01-01"
    delivery = deliveries(:monday_1)

    route = DepotGroup.create!(
      names: { en: "Route" },
      public_names: { en: "Route" })

    depots(:farm).update!(group: route)

    rows = summary_rows_for(delivery)

    route_row = rows.find { |row| row[0] == "Route" }
    ungrouped_row = rows.find { |row| row[0] == I18n.t("delivery.ungrouped_depots") }
    free_row = rows.find { |row| row[0] == I18n.t("delivery.free_depots") }
    paid_row = rows.find { |row| row[0] == I18n.t("delivery.paid_depots") }

    assert route_row, "Expected a Route subtotal row in the summary worksheet"
    assert ungrouped_row, "Expected an ungrouped depots subtotal row in the summary worksheet"
    assert_nil free_row
    assert_nil paid_row

    assert_equal 1, route_row[1].to_i
    assert_equal 2, ungrouped_row[1].to_i
  end

  test "home delivery overlay paints host street, city, and note" do
    travel_to "2024-04-01"
    members(:bob).update_column(:delivery_note, "Code 1234")
    HomeDeliveryAddress.create!(
      member: members(:bob),
      name: "Valentine Schneider",
      street: "Chantemerle 16",
      zip: "2000",
      city: "Neuchatel",
      note: "Leave at door",
      deliveries: [ deliveries(:monday_1) ])

    workbook = RubyXL::Parser.parse_buffer(StringIO.new(XLSX::Delivery.new(deliveries(:monday_1), depots(:home)).data))
    sheet = workbook.worksheets.first
    header = sheet.sheet_data[0].cells.map { |c| c&.value }
    street_col = header.index(Member.human_attribute_name(:street))
    zip_col = header.index(Member.human_attribute_name(:zip))
    city_col = header.index(Member.human_attribute_name(:city))
    note_col = header.index(Member.human_attribute_name(:note))
    bob_row = sheet.sheet_data.rows.compact.find { |row| row[0]&.value == "Bob Doe" }

    assert_equal zip_col, street_col + 1
    assert_equal city_col, zip_col + 1
    assert_includes bob_row[street_col].value, "Valentine Schneider"
    assert_includes bob_row[street_col].value, "Chantemerle 16"
    assert_equal "2000", bob_row[zip_col].value
    assert_equal "Neuchatel", bob_row[city_col].value
    assert_equal "Leave at door", bob_row[note_col].value
    assert bob_row[street_col].is_bolded
    assert bob_row[zip_col].is_bolded
    assert_equal "BBBBBB", bob_row[street_col].fill_color.upcase
    assert bob_row[note_col].is_bolded
  end
end

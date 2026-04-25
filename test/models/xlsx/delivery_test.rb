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
end

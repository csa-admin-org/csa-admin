# frozen_string_literal: true

require "test_helper"
require "rubyXL"
require "stringio"

class XLSX::BasketContentTest < ActiveSupport::TestCase
  def workbook_for(delivery)
    RubyXL::Parser.parse_buffer(StringIO.new(XLSX::BasketContent.new(delivery).data))
  end

  def rows_for(sheet)
    sheet.sheet_data.rows.compact.map do |row|
      row.cells.map { |cell| cell&.value }
    end
  end

  def column_index(rows, basket_size)
    rows.first.index("#{basket_size.name} - #{Basket.model_name.human(count: 2)}")
  end

  def config(small: 0, medium: 0, large: 0)
    baskets(:bob_1).update_column(:quantity, small)
    baskets(:john_1).update_column(:quantity, medium)
    baskets(:anna_1).update_column(:quantity, large)
  end

  test "does not export basket counts for sizes without product quantity" do
    delivery = deliveries(:monday_1)
    create_basket_content(
      delivery: delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { small_id => 100 },
      depots: Depot.all,
      unit: "pc")

    workbook = workbook_for(delivery)
    summary_rows = rows_for(workbook.worksheets.find { |sheet| sheet.sheet_name == I18n.t("delivery.summary") })
    farm_rows = rows_for(workbook.worksheets.find { |sheet| sheet.sheet_name == depots(:farm).name })

    summary_medium_count_column = column_index(summary_rows, basket_sizes(:medium))
    farm_medium_count_column = column_index(farm_rows, basket_sizes(:medium))

    assert_equal 0, summary_rows.second[summary_medium_count_column]
    assert_equal 0, farm_rows.second[farm_medium_count_column]
    assert_equal 0, farm_rows.second[farm_medium_count_column + 2]
  end

  test "writes money as numbers and rounds quantities to three decimals" do
    delivery = deliveries(:monday_1)
    create_basket_content(
      delivery: delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { small_id => 100, medium_id => 300 },
      depots: Depot.all,
      unit: "kg",
      unit_price: 1.2)

    workbook = workbook_for(delivery)
    summary = workbook.worksheets.find { |sheet| sheet.sheet_name == I18n.t("delivery.summary") }
    farm = workbook.worksheets.find { |sheet| sheet.sheet_name == depots(:farm).name }
    rows = rows_for(summary)
    price_column = rows.first.index("#{basket_sizes(:small).name} - #{BasketContent.human_attribute_name(:price)}")
    unit_price_column = rows.first.index(BasketContent.human_attribute_name(:unit_price))
    quantity_column = rows.first.index(BasketContent.human_attribute_name(:quantity))
    cell = summary[1][price_column]
    farm_cell = farm[1][price_column]

    assert_equal 0.12, cell.value
    assert_nil cell.datatype
    assert_equal "[$CHF] #,##0.00;[$CHF] -#,##0.00", cell.number_format.format_code
    assert_equal 1.2, summary[1][unit_price_column].value
    assert_nil farm_cell.datatype
    assert_equal 0, farm[1][rows.first.index("#{basket_sizes(:small).name} - #{Basket.model_name.human(count: 2)}")].value
    assert_equal 0.3, summary[1][rows.first.index("#{basket_sizes(:medium).name} - #{BasketContent.human_attribute_name(:basket_quantity)}")].value
    assert_equal "0.000", summary[1][quantity_column].number_format.format_code
  end

  test "adds a producers sheet for the delivery with amounts and percentages" do
    config(small: 2, medium: 1)
    delivery = deliveries(:monday_1)
    farm = producers(:farm)
    garden = Producer.create!(name: "Garden")
    basket_content_products(:carrots).update!(producer: farm)
    basket_content_products(:cucumbers).update!(producer: garden)
    create_basket_content(
      product: basket_content_products(:carrots),
      delivery: delivery,
      basket_size_ids_quantities: { small_id => 500, medium_id => 1000 },
      unit: "kg",
      unit_price: 4)
    create_basket_content(
      product: basket_content_products(:cucumbers),
      delivery: delivery,
      basket_size_ids_quantities: { small_id => 2, medium_id => 1 },
      unit: "pc",
      unit_price: 3)

    sheet = workbook_for(delivery).worksheets.find { |ws| ws.sheet_name == Producer.model_name.human(count: 2) }
    rows = rows_for(sheet)

    assert_equal [
      Producer.model_name.human,
      I18n.t("basket_content.producers.amount"),
      I18n.t("attributes.amount_percentage")
    ], rows.first
    assert_equal [ "Garden", 15, 0.65 ], rows.second
    assert_equal [ "Farm", 8, 0.35 ], rows.third
    assert_equal [ I18n.t("attributes.total"), 23, 1 ], rows.fourth
    assert_nil sheet[1][1].datatype
    assert_equal "[$CHF] #,##0.00;[$CHF] -#,##0.00", sheet[1][1].number_format.format_code
    assert_equal "0%", sheet[1][2].number_format.format_code
    assert sheet[3][0].is_bolded
  end

  test "skips the producers sheet without a priced producer" do
    delivery = deliveries(:monday_1)
    create_basket_content(
      delivery: delivery,
      basket_size_ids_quantities: { small_id => 1 },
      unit: "pc",
      unit_price: 2)

    names = workbook_for(delivery).worksheets.map(&:sheet_name)

    assert_not_includes names, Producer.model_name.human(count: 2)
  end

  test "producer sheet uses the current locale" do
    delivery = deliveries(:monday_1)
    basket_content_products(:carrots).update!(producer: producers(:farm))
    create_basket_content(
      delivery: delivery,
      product: basket_content_products(:carrots),
      basket_size_ids_quantities: { small_id => 500 },
      unit: "kg",
      unit_price: 2)

    I18n.with_locale(:fr) do
      names = workbook_for(delivery).worksheets.map(&:sheet_name)

      assert_includes names, "Producteurs"
    end
  end

  test "exports producer next to the product name" do
    delivery = deliveries(:monday_1)
    product = basket_content_products(:carrots)
    product.update!(producer: producers(:farm))
    create_basket_content(
      delivery: delivery,
      product: product,
      basket_size_ids_quantities: { small_id => 100 },
      depots: Depot.all,
      unit: "pc")

    rows = rows_for(workbook_for(delivery).worksheets.first)
    producer_column = rows.first.index(Producer.model_name.human)

    assert producer_column
    assert_equal "Farm", rows.second[producer_column]

    product.update!(producer: nil)
    blank_rows = rows_for(workbook_for(delivery).worksheets.first)

    assert_nil blank_rows.second[producer_column]
  end
end

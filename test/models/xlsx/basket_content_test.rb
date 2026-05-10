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
    assert_nil farm_rows.second[farm_medium_count_column]
  end
end

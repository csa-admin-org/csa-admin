# frozen_string_literal: true

require "test_helper"
require "rubyXL"
require "stringio"

class XLSX::BillingTest < ActiveSupport::TestCase
  def workbook_for(year = 2024)
    RubyXL::Parser.parse_buffer(StringIO.new(XLSX::Billing.new(year).data))
  end

  test "writes invoice and payment totals as currency numbers, including zeros" do
    travel_to "2024-04-01"
    sheet = workbook_for.worksheets.first
    rows = sheet.sheet_data.rows.compact
    invoices = rows.find { |row| row[0]&.value == Invoice.model_name.human(count: 2) }
    payments = rows.find { |row| row[0]&.value == Payment.model_name.human(count: 2) }
    adjustments = rows.find { |row|
      row[0]&.value == "#{I18n.t("billing.adjustments")}: #{Basket.model_name.human(count: 2)}"
    }
    format = '"CHF" #,##0.00;"CHF" -#,##0.00'

    assert_equal Invoice.not_canceled.during_year(2024).sum(:amount).to_f, invoices[2].value
    assert_nil invoices[2].datatype
    assert_equal format, invoices[2].number_format.format_code
    assert_equal Payment.during_year(2024).not_ignored.sum(:amount).to_f, payments[2].value
    assert_equal 0, adjustments[2].value
    assert_equal format, adjustments[2].number_format.format_code
  end

  test "keeps unit prices at three decimals and follows the organization currency" do
    travel_to "2024-04-01"
    Current.org.update!(currency_code: "EUR")
    basket_sizes(:small).update!(price: 10.125)
    sheet = workbook_for.worksheets.first
    row = sheet.sheet_data.rows.compact.find { |cells| cells[0]&.value&.include?(basket_sizes(:small).name) }

    assert_equal 10.125, row[1].value
    assert_equal '"€" #,##0.000;"€" -#,##0.000', row[1].number_format.format_code
    assert_equal '"€" #,##0.00;"€" -#,##0.00', row[2].number_format.format_code
  end
end

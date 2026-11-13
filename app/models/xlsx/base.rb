# frozen_string_literal: true

require "rubyXL"
require "rubyXL/convenience_methods"

module XLSX
  class Base
    include ActionView::Helpers::NumberHelper
    include ActionView::Helpers::TextHelper
    include NumbersHelper
    include ApplicationHelper
    include NumbersHelper

    delegate :content_type, to: :workbook

    def data
      workbook.stream.string
    end

    def filename
      raise NotImplementedError
    end

    def file
      {
        io: workbook.stream,
        filename: filename,
        content_type: content_type
      }
    end

    private

    def workbook
      @workbook ||= RubyXL::Workbook.new
    end

    def add_worksheet(name)
      name = name.gsub(RubyXL::Workbook::SHEET_NAME_FORBIDDEN_CHARS, " ")
      if !@first_worksheet_used
        @worksheet = workbook.worksheets[0]
        @worksheet.sheet_name = name
        @first_worksheet_used = true
      else
        @worksheet = workbook.add_worksheet(name)
      end
      @line = 1
      @column = 0
      @worksheet
    end

    def add_headers(*cols)
      cols.each_with_index do |col, i|
        @worksheet.add_cell(0, i, col)
      end
      @worksheet.change_row_bold(0, true)
    end

    def add_column(header, values, border: "none", align: "left", max_width: nil, min_width: 5, format: nil)
      @worksheet.add_cell(0, @column, header)
      @worksheet.sheet_data[0][@column].change_font_bold(true)

      Array(values).each_with_index do |val, i|
        cell = @worksheet.add_cell(i + 1, @column, val)
        cell.set_number_format(format) if format && !val.nil?
        cell.change_text_wrap(true) if val.is_a?(String) && val.include?("\n")
      end

      max_width ||= ([ header ] + Array(values)).map { |value| value.to_s.length }.max.to_i + 2
      @worksheet.change_column_width(@column, [ min_width, max_width ].max)

      if border != "none"
        @worksheet.change_column_border(@column, :top, border)
        @worksheet.change_column_border(@column, :bottom, border)
        @worksheet.change_column_border(@column, :left, border)
        @worksheet.change_column_border(@column, :right, border)
      end
      @worksheet.change_column_horizontal_alignment(@column, align)

      @column += 1
    end

    def add_money_cell(row, column, amount, precision: 2)
      cell = @worksheet.add_cell(row, column, money(amount, precision:))
      cell.set_number_format(money_format(precision)) unless amount.nil?
      cell
    end

    def add_count_cell(row, column, amount)
      @worksheet.add_cell(row, column, count(amount)).set_number_format(count_format)
    end

    def add_quantity_cell(row, column, amount)
      @worksheet.add_cell(row, column, quantity(amount)).set_number_format(flexible_quantity_format)
    end

    def add_empty_line
      @worksheet.add_cell(@line, 0)
      @line += 1
    end

    def t(key, **args)
      I18n.t("billing.#{key}", **args)
    end

    def money(amount, precision: 2)
      return if amount.nil?

      BigDecimal(amount.to_s).round(precision, :half_up).to_f
    end

    def quantity(amount, precision: 3)
      BigDecimal((amount || 0).to_s).round(precision, :half_up).to_f
    end

    def count(amount)
      (amount || 0).to_i
    end

    def money_price(unit_price, amount)
      return if unit_price.nil?

      money(BigDecimal(unit_price.to_s) * BigDecimal((amount || 0).to_s))
    end

    # [$CHF] is a currency token. A quoted "CHF" is text, which Numbers, Excel,
    # and LibreOffice file under Custom instead of Currency.
    def money_format(precision = 2)
      decimals = "0" * precision
      number = precision.positive? ? "#,##0.#{decimals}" : "#,##0"
      token = "[\$#{currency_symbol}]"
      "#{token} #{number};#{token} -#{number}"
    end

    def quantity_format(precision = 3)
      precision.positive? ? "0.#{"0" * precision}" : count_format
    end

    def count_format
      "0"
    end

    def flexible_quantity_format
      "0.##"
    end

    def percentage_format
      "0%"
    end
  end
end

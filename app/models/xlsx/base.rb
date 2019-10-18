require 'rubyXL/convenience_methods'

module XLSX
  class Base
    include ActionView::Helpers::NumberHelper

    delegate :content_type, to: :workbook

    def data
      workbook.stream.string
    end

    def filename
      raise NotImplementedError
    end

    private

    def workbook
      @workbook ||= RubyXL::Workbook.new
    end

    def add_worksheet(name)
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

    def add_column(header, values, border: 'none')
      @worksheet.add_cell(0, @column, header)
      @worksheet.sheet_data[0][@column].change_font_bold(true)

      Array(values).each_with_index do |val, i|
        @worksheet.add_cell(i + 1, @column, val)
      end

      max_width = Array(values).map { |v| v.to_s.length }.max
      @worksheet.change_column_width(@column, max_width + 1)

      if border != 'none'
        @worksheet.change_column_border(@column, :top, border)
        @worksheet.change_column_border(@column, :bottom, border)
        @worksheet.change_column_border(@column, :left, border)
        @worksheet.change_column_border(@column, :right, border)
      end

      @column += 1
    end

    def add_empty_line
      @worksheet.add_cell(@line, 0)
      @line += 1
    end
  end
end

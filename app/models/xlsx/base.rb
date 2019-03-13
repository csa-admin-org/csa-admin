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
      @worksheet
    end

    def add_header(*cols)
      cols.each_with_index do |col, i|
        @worksheet.add_cell(0, i, col)
      end
      @worksheet.change_row_bold(0, true)
    end

    def add_empty_line
      @worksheet.add_cell(@line, 0)
      @line += 1
    end
  end
end

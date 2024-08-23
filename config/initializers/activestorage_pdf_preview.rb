# frozen_string_literal: true

module ActiveStorage
  class Previewer::PopplerPDFPreviewer < Previewer
    # Patch to increase resolution of the PDF preview image
    RESOLUTION = 72 * 2

    private
      def draw_first_page_from(file, &block)
        # use 72 dpi to match thumbnail dimensions of the PDF
        draw self.class.pdftoppm_path, "-singlefile", "-cropbox", "-r", "#{RESOLUTION}", "-png", file.path, &block
      end
  end
end

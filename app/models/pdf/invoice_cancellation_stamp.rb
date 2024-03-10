module PDF
  class InvoiceCancellationStamp
    def self.stamp!(path)
      new(path).stamp!
    end

    def initialize(path)
      @path = path
      @pdf = HexaPDF::Document.open(@path)
    end

    def stamp!
      @pdf.pages.each do |page|
        canvas = page.canvas(type: :overlay)
        canvas.rotate(10) do
          canvas.opacity(fill_alpha: 0.25) do
            canvas.image(stamp_path, at: [ 129, 520 ], height: 110)
          end
        end
      end
      @pdf.write(@path, optimize: true)
    end

    def stamp_path
      @stamp_path ||=
        Rails.root.join("app/assets/images/admin/canceled.#{I18n.locale}.png").to_s
    end
  end
end

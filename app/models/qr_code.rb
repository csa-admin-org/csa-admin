# frozen_string_literal: true

require "rqrcode"

class QRCode
  def initialize(payload, logo: nil)
    @payload = payload
    @logo = logo
  end

  def image
    return placeholder_image if show_placeholder?

    png = qr_png
    if @logo
      overlay = logo_png
      png.compose!(overlay, (png.width - overlay.width) / 2, (png.height - overlay.height) / 2)
    end
    png_file(png.to_blob)
  end

  private

  def png_file(data)
    file = Tempfile.new([ "qr", ".png" ])
    file.binmode
    file.write(data)
    file.rewind
    file
  end

  def logo_png
    path = Rails.root.join("lib", "assets", "images", "#{@logo}.png")
    ChunkyPNG::Image.from_file(path.to_s)
  end

  def qr_png
    qrcode = RQRCode::QRCode.new(@payload, level: :m)
    qrcode
      .as_png(border_modules: 0, module_px_size: 1)
      .resample_nearest_neighbor(1024, 1024)
  end

  # Generating the QR code image is slow so we skip it for performance reasons
  # in the test env.
  def show_placeholder?
    Rails.env.test? && !ENV["SKIP_QR_CODE_PLACEHOLDER"]
  end

  def placeholder_image
    File.new(Rails.root.join("test", "fixtures", "files", "qrcode-test.png"))
  end
end

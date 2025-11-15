# frozen_string_literal: true

class QRCode
  LOGO_SIZE = 166

  def initialize(payload, logo: nil)
    @payload = payload
    @logo = logo
  end

  def image
    return placeholder_image if show_placeholder?

    qr_image = Vips::Image.new_from_buffer(blob, "")
    ImageProcessing::Vips
      .source(qr_image)
      .composite(logo_image, gravity: :centre)
      .convert(:png)
      .call
  end

  private

  def logo_image
    path = Rails.root.join("lib", "assets", "images", "#{@logo}.png")
    ImageProcessing::Vips.source(path).resize_to_limit!(LOGO_SIZE, LOGO_SIZE)
  end

  def blob
    qrcode = RQRCode::QRCode.new(@payload, level: :m)
    qrcode.as_png(
      border_modules: 0,
      module_px_size: 6,
      size: 1024
    ).to_blob
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

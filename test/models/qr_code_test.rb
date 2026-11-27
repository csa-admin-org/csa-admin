# frozen_string_literal: true

require "test_helper"
require "chunky_png"

class QRCodeTest < ActiveSupport::TestCase
  test "generates a 1024x1024 Prawn-compatible PNG without a logo" do
    skip_qr_code_placeholder do
      bytes = QRCode.new("https://csa-admin.org").image.read
      png = ChunkyPNG::Image.from_blob(bytes)
      prawn_info = Prawn.image_handler.find(bytes).new(bytes)

      assert_equal 1024, png.width
      assert_equal 1024, png.height
      assert_equal 1024, prawn_info.width
      assert_equal 1024, prawn_info.height
    end
  end

  test "composites the swiss_cross logo onto the center of the QR code" do
    skip_qr_code_placeholder do
      plain = ChunkyPNG::Image.from_blob(QRCode.new("https://csa-admin.org").image.read)
      bytes = QRCode.new("https://csa-admin.org", logo: :swiss_cross).image.read
      png = ChunkyPNG::Image.from_blob(bytes)
      prawn_info = Prawn.image_handler.find(bytes).new(bytes)

      assert_equal 1024, png.width
      assert_equal 1024, png.height
      assert_equal 1024, prawn_info.width
      assert_not_equal plain.crop(430, 430, 160, 160), png.crop(430, 430, 160, 160)
    end
  end

  test "composites the radis logo onto the center of the QR code" do
    skip_qr_code_placeholder do
      plain = ChunkyPNG::Image.from_blob(QRCode.new("https://csa-admin.org").image.read)
      bytes = QRCode.new("https://csa-admin.org", logo: :radis).image.read
      png = ChunkyPNG::Image.from_blob(bytes)
      prawn_info = Prawn.image_handler.find(bytes).new(bytes)

      assert_equal 1024, png.width
      assert_equal 1024, png.height
      assert_equal 1024, prawn_info.width
      assert_not_equal plain.crop(430, 430, 160, 160), png.crop(430, 430, 160, 160)
    end
  end
end

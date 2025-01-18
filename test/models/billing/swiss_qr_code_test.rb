# frozen_string_literal: true

require "test_helper"
require "image_processing/vips"

class Billing::SwissQRCodeTest < ActiveSupport::TestCase
  test "payload" do
    invoice = invoices(:annual_fee)
    payload = Billing::SwissQRCode.new(invoice).payload

    assert_equal(
      "SPC\r\n" +
      "0200\r\n" +
      "1\r\n" +
      "CH4431999123000889012\r\n" +
      "S\r\n" +
      "Acme\r\n" +
      "Nowhere 42\r\n" +
      "\r\n" +
      "1234\r\n" +
      "City\r\n" +
      "CH\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "\r\n" +
      "30.00\r\n" +
      "CHF\r\n" +
      "S\r\n" +
      "Martha\r\n" +
      "Nowhere 46\r\n" +
      "\r\n" +
      "1234\r\n" +
      "City\r\n" +
      "CH\r\n" +
      "QRR\r\n" +
      "#{swiss_qr_ref(invoice)}\r\n" +
      "Invoice #{invoice.id}\r\n" +
      "EPD\r\n" +
      "\r\n",
      payload)
  end

  test "generated QR check" do
    expected = Vips::Image.new_from_file(file_fixture("qrcode-check.png").to_s)
    member = create_member(
      id: 1234,
      name: "Martha",
      address: "Nowhere 46",
      zip: "1234",
      city: "City",
      country_code: "CH")
    invoice = create_annual_fee_invoice(
      id: 4321,
      member: member,
      date: "2024-01-01")

    qr_image = Billing::SwissQRCode.new(invoice).generate(rails_env: "not_test")
    # FileUtils.cp(qr_image.path, file_fixture("qrcode-check.png"))
    result = Vips::Image.new_from_file(qr_image.path)
    diff = (result - expected).abs.max

    assert_equal 0, diff
  end
end

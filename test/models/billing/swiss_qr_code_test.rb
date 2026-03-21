# frozen_string_literal: true

require "test_helper"


class Billing::SwissQRCodeTest < ActiveSupport::TestCase
  test "payload" do
    invoice = invoices(:annual_fee)
    invoice.member.update_columns(
      name: "VIŠČEK João Münster",
      street: "Saarstraße 7")
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
      "VISCEK Joao Münster\r\n" +
      "Saarstraße 7\r\n" +
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
end

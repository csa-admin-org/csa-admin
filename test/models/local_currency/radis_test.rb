# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class LocalCurrency::RadisTest < ActiveSupport::TestCase
  setup do
    org(
      features: [ "local_currency" ],
      local_currency_code: "RAD",
      local_currency_identifier: "133",
      local_currency_wallet: "1234567890abcdef")
  end

  test "payment_payload" do
    invoice = invoices(:annual_fee)
    assert_equal({
      rp: 133,
      rpb: "comchain:1234567890abcdef",
      amount: "30.0",
      senderMemo: "00 00000 06148 57506 38928 10045",
      recipientMemo: "00 00000 06148 57506 38928 10045"
    }, LocalCurrency::Radis.payment_payload(invoice))
  end
end

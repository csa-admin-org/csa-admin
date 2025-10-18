# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class LocalCurrency::ComChainTest < ActiveSupport::TestCase
  setup do
    org(
      features: [ "local_currency" ],
      local_currency_code: "RAD",
      local_currency_identifier: "test_shop",
      local_currency_wallet: "0x1234567890abcdef")
  end

  test "payment_url" do
    invoice = invoices(:annual_fee)
    url = LocalCurrency::ComChain.payment_url(invoice)

    assert_includes url, "https://com-chain.org/pay/comchain_webhook_getway.php"
    assert_includes url, "ShopId=test_shop"
    assert_includes url, "TargetWallet=0x1234567890abcdef"
    assert_includes url, "ServerName=ComChainRadis"
    assert_includes url, "Total=30.0"
    assert_includes url, "TrnId=#{invoice.reference}"
    assert_includes url, "ReturnURL=https%3A%2F%2Fmembers.acme.test%2Fpayments%2Fconfirmation"
    assert_includes url, "logoURL=https%3A%2F%2Fadmin.acme.test%2Fimages%2Flogo.png"
  end

  test "verify_signature invalid" do
    json_str = '{"test": "data"}'
    headers = {
      "COMCHAIN-TRANSMISSION-SIG" => "invalid",
      "COMCHAIN-CERT-URL" => "https://example.com/cert"
    }

    assert_not LocalCurrency::ComChain.verify_signature(json_str, headers)
  end

  test "verify_signature valid" do
    json_str = '{"test": "data"}'
    crc = Zlib.crc32(json_str)
    crc_bytes = [ crc ].pack("N")

    private_key = OpenSSL::PKey::RSA.new(2048)
    signature = private_key.sign(OpenSSL::Digest::SHA1.new, crc_bytes)
    sig_b64 = Base64.encode64(signature)

    headers = {
      "COMCHAIN-TRANSMISSION-SIG" => sig_b64
    }

    Rails.application.credentials.stub :comchain_cert_public_key, private_key.public_key.to_pem do
      assert LocalCurrency::ComChain.verify_signature(json_str, headers)
    end
  end

  test "handle_webhook creates payment" do
    invoice = invoices(:annual_fee)
    invoice.update!(currency_code: "RAD")

    data = {
      "id" => "tx_hash_456",
      "create_time" => "2024-01-01T12:00:00Z",
      "resource" => {
        "id" => "tx_hash_456",
        "addr_to" => "0x1234567890abcdef",
        "reference" => invoice.reference.to_s,
        "amount" => {
          "sent" => 3000
        }
      }
    }

    Billing::ScorReference.stub :payload, { member_id: invoice.member_id, invoice_id: invoice.id } do
      assert_difference -> { Payment.count }, 1 do
        LocalCurrency::ComChain.handle_webhook(data)
      end

      payment = Payment.find_by(fingerprint: "tx_hash_456")
      assert_equal invoice.member, payment.member
      assert_equal invoice, payment.invoice
      assert_equal 30.0, payment.amount
      assert_equal "tx_hash_456", payment.fingerprint
    end
  end

  test "handle_webhook ignores invalid wallet" do
    invoice = invoices(:annual_fee)

    data = {
      "resource" => {
        "addr_to" => "invalid_wallet",
        "reference" => invoice.reference.to_s,
        "amount" => { "sent" => 3000 }
      }
    }

    assert_no_difference -> { Payment.count } do
      LocalCurrency::ComChain.handle_webhook(data)
    end
  end

  test "handle_webhook ignores invalid reference" do
    data = {
      "resource" => {
        "addr_to" => "0x1234567890abcdef",
        "reference" => "invalid_ref",
        "amount" => { "sent" => 3000 }
      }
    }

    assert_no_difference -> { Payment.count } do
      LocalCurrency::ComChain.handle_webhook(data)
    end
  end

  test "handle_webhook ignores mismatched amount" do
    invoice = invoices(:annual_fee)

    data = {
      "resource" => {
        "addr_to" => "0x1234567890abcdef",
        "reference" => invoice.reference.to_s,
        "amount" => { "sent" => 1000 }  # 10.00 instead of 30.00
      }
    }

    assert_no_difference -> { Payment.count } do
      LocalCurrency::ComChain.handle_webhook(data)
    end
  end
end

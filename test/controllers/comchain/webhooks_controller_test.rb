# frozen_string_literal: true

require "test_helper"
require "minitest/mock"

class Comchain::WebhooksControllerTest < ActionDispatch::IntegrationTest
  setup do
    org(
      features: [ "local_currency" ],
      local_currency_code: "RAD",
      local_currency_identifier: "test_shop",
      local_currency_wallet: "0x1234567890abcdef")
  end

  def webhook_request(json_payload, headers = {})
    default_headers = {
      "ACCEPT" => "application/json",
      "CONTENT_TYPE" => "application/json"
    }.merge(headers)

    host! "admin.acme.test"
    post "/comchain/webhooks", headers: default_headers, params: json_payload.to_json
  end

  test "returns unprocessable_entity when local_currency feature is disabled" do
    org(features: [])
    json_payload = { "test" => "data" }

    webhook_request(json_payload)
    assert_response :unprocessable_entity
  end

  test "returns bad_request for invalid signature" do
    json_payload = { "test" => "data" }
    headers = {
      "COMCHAIN-TRANSMISSION-SIG" => "invalid_sig",
      "COMCHAIN-CERT-URL" => "https://example.com/cert"
    }

    webhook_request(json_payload, headers)
    assert_response :bad_request
  end

  test "returns ok and enqueues job for valid signature" do
    json_payload = {
      "id" => "tx_123",
      "resource" => {
        "id" => "tx_123",
        "addr_to" => "0x1234567890abcdef",
        "reference" => "RF120000000003139471430009017",
        "amount" => { "sent" => 3000 }
      }
    }

    LocalCurrency::ComChain.stub :verify_signature, true do
      assert_enqueued_jobs 1 do
        webhook_request(json_payload)
      end
      assert_response :ok
    end
  end

  test "processes valid webhook and creates payment" do
    invoice = invoices(:annual_fee)
    invoice.update!(currency_code: "RAD")

    json_payload = {
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

    LocalCurrency::ComChain.stub :verify_signature, true do
      Billing::ScorReference.stub :payload, { member_id: invoice.member_id, invoice_id: invoice.id } do
        assert_difference -> { Payment.count }, 1 do
          webhook_request(json_payload)
          perform_enqueued_jobs
        end

        payment = Payment.find_by(fingerprint: "tx_hash_456")
        assert_equal invoice.member, payment.member
        assert_equal invoice, payment.invoice
        assert_equal 30.0, payment.amount
        assert_equal "tx_hash_456", payment.fingerprint
      end
    end
  end
end

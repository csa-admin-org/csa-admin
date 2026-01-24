# frozen_string_literal: true

require "rqrcode"
require "ostruct"

module LocalCurrency
  class Radis
    extend OrganizationsHelper
    extend ActionView::Helpers::AssetUrlHelper

    CODE = "RAD"
    PAYMENTS_ENDPOINT_URL = "https://node-cc-001.cchosting.org/tx_msg.php"
    PaymentData = Class.new(OpenStruct)

    def self.payment_payload(invoice)
      {
        rp: Current.org.local_currency_identifier.to_i,
        rpb: "comchain:#{Current.org.local_currency_wallet}",
        amount: invoice.missing_amount.to_s,
        senderMemo: invoice.reference.formatted,
        recipientMemo: invoice.reference.formatted
      }
    end

    def self.qr_code(invoice)
      QRCode.new(payment_payload(invoice).to_json, logo: :radis).image
    end

    def self.payments_data
      blockchain_transactions.map do |tx|
        next unless tx["msg"].present? && Billing.reference.valid?(tx["msg"])

        payload = Billing.reference.payload(tx["msg"])
        PaymentData.new(
          origin: "radis",
          fingerprint: tx["hash"],
          member_id: payload[:member_id],
          invoice_id: payload[:invoice_id],
          amount: tx["amount"],
          date: Time.at(tx["time"]).to_date
        )
      end.compact
    end

    private

    def self.blockchain_transactions
      res = nil
      uri = URI(PAYMENTS_ENDPOINT_URL)
      params = {
        addr: "0x#{Current.org.local_currency_wallet}",
        max_count: 100
      }
      uri.query = URI.encode_www_form(params)
      req = Net::HTTP::Get.new(uri)
      req["X-COMCHAIN-MESSAGE-KEY"] = Current.org.local_currency_secret
      res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(req)
      end
      JSON.parse(res.body)
    rescue StandardError => e
      Rails.error.report(e, context: { body: res&.body })
      []
    end
  end
end

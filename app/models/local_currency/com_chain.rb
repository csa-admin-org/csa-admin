# frozen_string_literal: true

require "rqrcode"
require "open-uri"
require "zlib"
require "openssl"

module LocalCurrency
  class ComChain
    extend OrganizationsHelper
    extend ActionView::Helpers::AssetUrlHelper

    BASE_URL = "https://com-chain.org/pay/comchain_webhook_getway.php"
    SERVER_NAME = "ComChainRadis"

    def self.payment_url(invoice)
      params = {
        ShopId: Current.org.local_currency_identifier,
        TargetWallet: Current.org.local_currency_wallet,
        ServerName: SERVER_NAME,
        Total: invoice.missing_amount,
        TrnId: invoice.reference.to_s,
        ReturnURL: Rails.application.routes.url_helpers.members_payment_confirmation_url(host: Current.org.members_url),
        logoURL: org_logo_url
      }.compact

      "#{BASE_URL}?#{params.to_query}"
    end

    def self.qr_code(invoice)
      QRCode.new(payment_url(invoice), logo: :radis).image
    end

    def self.verify_signature(json_str, headers)
      crc = Zlib.crc32(json_str)
      crc_bytes = [ crc ].pack("N")

      sig_b64 = headers["COMCHAIN-TRANSMISSION-SIG"]
      sig = Base64.decode64(sig_b64)

      cert_url = headers["COMCHAIN-CERT-URL"]
      cert_pem = URI.open(cert_url).read
      public_key = OpenSSL::PKey::RSA.new(cert_pem)

      public_key.verify(OpenSSL::Digest::SHA1.new, sig, crc_bytes)
    rescue
      false
    end

    def self.handle_webhook(data)
      resource = data["resource"]

      return unless resource["addr_to"].downcase == Current.org.local_currency_wallet.downcase

      payload = Billing.reference(Current.org).payload(resource["reference"])
      return unless payload

      invoice = Invoice.find_by(id: payload[:invoice_id], member_id: payload[:member_id])
      return unless invoice

      return unless (resource["amount"]["sent"] / 100.0) == invoice.missing_amount

      Payment.create!(
        member: invoice.member,
        invoice: invoice,
        currency_code: Current.org.local_currency_code,
        amount: resource["amount"]["sent"] / 100.0, # get decimal value
        date: Time.parse(data["create_time"]),
        fingerprint: resource["id"]
      )
    rescue ActiveRecord::RecordNotUnique
      # ignore duplicate payments
    end
  end
end

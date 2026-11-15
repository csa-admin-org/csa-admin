# frozen_string_literal: true

require "image_processing/vips"
require "rqrcode"

# QR Payload specification: https://www.paymentstandards.ch/dam/downloads/ig-qr-bill-en.pdf
# QR Validator: https://www.swiss-qr-invoice.org/validator/?lang=fr

module Billing
  class SwissQRCode
    # Allowed characters (as a single-character regex) per Swiss QR Bill:
    ALLOWED_CHAR_REGEX = /[a-zA-Z0-9\.,;:'\+\-\/\(\)?\*\[\]\{\}\|\\`´~ !"#%&<>÷=@_$£^àáâäçèéêëìíîïñòóôöùúûüýßÀÁÂÄÇÈÉÊËÌÍÎÏÒÓÔÖÙÚÛÜÑ]/

    def self.image(invoice)
      new(invoice).image
    end

    def initialize(invoice)
      @invoice = invoice
      @member = invoice.member
      @org = Current.org
    end

    def image
      QRCode.new(payload, logo: :swiss_cross).image
    end

    def payload
      [
        "SPC",
        "0200",
        "1",
        @org.iban,
        "S",
        transliterate(@org.creditor_name).truncate(70),
        transliterate(@org.creditor_street).truncate(70),
        "",
        transliterate(@org.creditor_zip),
        transliterate(@org.creditor_city).truncate(70),
        @org.country_code,
        "",
        "",
        "",
        "",
        "",
        "",
        "",
        sprintf("%.2f", @invoice.missing_amount),
        @org.currency_code,
        "S",
        transliterate(@member.name).truncate(70),
        transliterate(@member.street).truncate(70),
        "",
        transliterate(@member.zip),
        transliterate(@member.city).truncate(70),
        @member.country_code,
        "QRR",
        @invoice.reference.to_s,
        "#{Invoice.model_name.human} #{@invoice.id}",
        "EPD",
        "",
        ""
      ].join("\r\n")
    end

    private

    def transliterate(string)
      string.chars.map { |char|
        char.match?(ALLOWED_CHAR_REGEX) ? char : I18n.transliterate(char)
      }.join
    end
  end
end

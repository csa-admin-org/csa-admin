# frozen_string_literal: true

require "image_processing/vips"
require "rqrcode"

# QR Payload specification: https://www.paymentstandards.ch/dam/downloads/ig-qr-bill-en.pdf
# QR Validator: https://www.swiss-qr-invoice.org/validator/?lang=fr

# SPC                                # indicator for swiss qr code: SPC (swiss payments code)
# 0200                               # version of the specifications, 0200 = v2.0
# 1                                  # character set code: 1 = utf-8 restricted to the latin character set
# CH4431999123000889012              # iban of the creditor (payable to)
# S                                  # adress type: S = structured address, K = combined address elements (2 lines)
# Robert Schneider AG                # creditor's name or company, max 70 characters
# Via Casa Postale                   # structured address: creditor's address street; combined address: address line 1 street and building number
# 1268/2/22                          # structured address: creditor's building number; combined address: address line 2 including postal code and town
# 2501                               # creditor's postal code
# Biel                               # creditor's town
# CH                                 # creditor's country
#                                    # optional: ultimate creditor's address type: S/K
#                                    # optional: ultimate creditor's name/company
#                                    # optional: ultimate creditor's street or address line 1
#                                    # optional: ultimate creditor's building number or address line 2
#                                    # optional: ultimate creditor's postal code
#                                    # optional: ultimate creditor's town
#                                    # optional: ultimate creditor's country
# 123949.75                          # amount
# CHF                                # currency
# S                                  # debtor's address type (S/K) (payable by)
# Pia-Maria Rutschmann-Schnyder      # debtor's name / company
# Grosse Marktgasse                  # debtor's street or address line 1
# 28/5                               # debtor's building number or address line 2
# 9400                               # debtor's postal code
# Rorschach                          # debtor's town
# CH                                 # debtor's country
# QRR                                # reference type: QRR = QR reference, SCOR = Creditor reference, NON = without reference
# 210000000003139471430009017        # reference QR Reference: 27 chars check sum modulo 10 recursive, Creditor reference max 25 chars
# Blah blah blach 23.02.2017!        # additional information unstructured message max 140 chars
# EPD                                # fixed indicator for EPD (end payment data)
# //S1/10/10201409/11/181105/40/0:30 # bill information coded for automated booking of payment, data is not forwarded with the payment
# eBill/B/41010560425                # alternative scheme paramaters, max 100 chars

module Billing
  class SwissQRCode
    # Allowed characters (as a single-character regex) per Swiss QR Bill:
    ALLOWED_CHAR_REGEX = /[a-zA-Z0-9\.,;:'\+\-\/\(\)?\*\[\]\{\}\|\\`´~ !"#%&<>÷=@_$£^àáâäçèéêëìíîïñòóôöùúûüýßÀÁÂÄÇÈÉÊËÌÍÎÏÒÓÔÖÙÚÛÜÑ]/

    def self.generate(invoice)
      new(invoice).generate
    end

    def initialize(invoice)
      @invoice = invoice
      @member = invoice.member
      @org = Current.org
    end

    def generate(rails_env: Rails.env)
      # Generating the QR code image is slow so we skip it for performance reasons
      # in the test env.
      if rails_env == "test"
        File.new(Rails.root.join("test", "fixtures", "files", "qrcode-test.png"))
      else
        qrcode_image.composite(logo_image, gravity: :centre).convert(:png).call
      end
    end

    def payload
      [
        "SPC",
        "0200",
        "1",
        @org.iban,
        "S",
        transliterate(@org.creditor_name).truncate(70),
        transliterate(@org.creditor_address).truncate(70),
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
        transliterate(@member.address).truncate(70),
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

    def qrcode_image
      vips_image = Vips::Image.new_from_buffer(qrcode_png_blob, "")
      ImageProcessing::Vips.source(vips_image)
    end

    def qrcode_png_blob
      qrcode = RQRCode::QRCode.new(payload, level: :m)
      qrcode.as_png(
        border_modules: 0,
        module_px_size: 6,
        size: 1024
      ).to_blob
    end

    def logo_image
      path = "#{Rails.root}/lib/assets/images/swiss_cross.png"
      ImageProcessing::Vips.source(path)
        .resize_to_limit!(166, 166)
    end

    def transliterate(string)
      string.chars.map { |char|
        char.match?(ALLOWED_CHAR_REGEX) ? char : I18n.transliterate(char)
      }.join
    end
  end
end

# frozen_string_literal: true

# European Payments Council: Quick Response Code
# https://github.com/mtgrosser/girocode

module Billing
  class EPCQRCode
    def self.generate(invoice)
      new(invoice).generate
    end

    def initialize(invoice)
      @invoice = invoice
      @acp = Current.acp
      @code = build_code
    end

    def generate
      @code.to_svg
    end

    private

    def build_code
      attrs = {
        iban: @acp.iban,
        name: @acp.creditor_name,
        currency: @acp.currency_code,
        reference: @invoice.reference.to_s
      }
      unless @invoice.missing_amount.zero?
        attrs[:amount] = @invoice.missing_amount
      end
      Girocode.new(**attrs)
    end
  end
end

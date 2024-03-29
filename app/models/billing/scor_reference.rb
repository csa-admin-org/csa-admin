# Structured Creditor Reference (référence type SCOR) ISO-11649
# https://www.mobilefish.com/services/creditor_reference/creditor_reference.php

module Billing
  class ScorReference
    PREFIX = "RF"
    MAPPING = ("A".."Z").to_a.zip((10..35).to_a).to_h.freeze
    REF_PART_SIZE = 8
    REGEPX = /\ARF\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\z/

    attr_accessor :invoice

    def initialize(invoice)
      @invoice = invoice
      @ref = add_checksum("#{member_ref}#{invoice_ref}")
    end

    def to_s
      @ref
    end

    def formatted
      @ref.chars.each_slice(4).map(&:join).join(" ")
    end

    def self.valid?(ref)
      ref.present? && ref.match?(REGEPX)
    end

    def self.unknown?(ref)
      ref.present? && !ref.start_with?("RF")
    end

    def self.payload(ref)
      ref = ref.delete(" ")
      {
        member_id: ref.last(16).first(8).to_i,
        invoice_id: ref.last(8).to_i
      }
    end

    private

    def member_ref
      ref = @invoice.member_id.to_s
      ref.prepend("0") until ref.length == REF_PART_SIZE
      ref
    end

    def invoice_ref
      @invoice_ref ||= begin
        ref = @invoice.id.to_s
        ref.prepend("0") until ref.length == REF_PART_SIZE
        ref
      end
    end

    def add_checksum(ref)
      "#{PREFIX}#{checksum(ref)}#{ref}"
    end

    def checksum(ref)
      mapped = ref + MAPPING["R"].to_s + MAPPING["F"].to_s + "00"
      val = 98 - (mapped.to_i % 97)
      val < 10 ? val.to_s.prepend("0") : val
    end
  end
end

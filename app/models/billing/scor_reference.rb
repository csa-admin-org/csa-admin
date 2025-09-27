# frozen_string_literal: true

# Structured Creditor Reference (référence type SCOR) ISO-11649
# https://www.mobilefish.com/services/creditor_reference/creditor_reference.php

module Billing
  class ScorReference
    PREFIX = "RF"
    MAPPING = ("A".."Z").to_a.zip((10..35).to_a).to_h.freeze
    REF_PART_SIZE = 8
    REGEXP = /\A.*?(RF\d{18}).*\z/

    attr_accessor :invoice

    def initialize(invoice)
      @invoice = invoice
      @ref = add_checksum("#{build_ref(invoice.member_id)}#{build_ref(invoice.id)}")
    end

    def to_s
      @ref
    end

    def formatted
      @ref.chars.each_slice(4).map(&:join).join(" ")
    end

    def self.valid?(ref)
      ref = extract_ref(ref)
      return unless ref.present?

      payload = payload(ref)
      invoice = OpenStruct.new(
        id: payload[:invoice_id],
        member_id: payload[:member_id])
      new(invoice).to_s == ref
    end

    def self.unknown?(ref)
      ref.present? && !ref.start_with?("RF")
    end

    def self.payload(ref)
      ref = extract_ref(ref)
      {
        member_id: ref.last(16).first(8).to_i,
        invoice_id: ref.last(8).to_i
      }
    end

    def self.extract_ref(ref)
      return unless ref.present?

      ref.gsub(/\W/, "").upcase[REGEXP, 1]
    end

    private

    def build_ref(id)
      ref = id.to_s
      if ref.length < REF_PART_SIZE
        ref.prepend("0") until ref.length == REF_PART_SIZE
      else
        ref = ref.last(REF_PART_SIZE)
      end
      ref
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

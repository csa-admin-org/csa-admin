module Billing
  class SwissQRReference
    LENGTH = 27
    INVOICE_REF_LENGTH = 9
    CHECKSUM_SERIES = [ 0, 9, 4, 6, 8, 2, 7, 1, 3, 5 ].freeze

    attr_accessor :invoice

    def initialize(invoice)
      @invoice = invoice
      @ref = add_checksum_digit("#{bank_ref}#{member_ref}#{invoice_ref}")
    end

    def to_s
      @ref
    end

    def formatted
      @ref
        .delete(" ")
        .reverse
        .gsub(/(.{5})(?=.)/, '\1 \2')
        .reverse
    end

    def self.valid?(ref)
      ref = ref.upcase.gsub(/\W/, "")
      return unless ref.present? && ref =~ /\A\d+\z/ && ref.length == LENGTH

      payload = payload(ref)
      invoice = OpenStruct.new(
        id: payload[:invoice_id],
        member_id: payload[:member_id])
      new(invoice).to_s.upcase == ref
    end

    def self.unknown?(ref)
      ref.present? && !ref.start_with?("RF")
    end

    def self.payload(ref)
      ref = ref.upcase.gsub(/\W/, "")
      member_id = ref.last(20).first(10).to_i
      {
        member_id: member_id.zero? ? nil : member_id,
        invoice_id: ref.last(10).first(9).to_i
      }
    end

    private

    def member_ref
      ref = @invoice.member_id.to_s
      ref.prepend("0") until ref.length == member_ref_length
      ref
    end

    def invoice_ref
      @invoice_ref ||= begin
        ref = @invoice.id.to_s
        ref.prepend("0") until ref.length >= INVOICE_REF_LENGTH
        ref
      end
    end

    def member_ref_length
      @member_ref_length ||= LENGTH - invoice_ref.length - bank_ref.to_s.length - 1 # 1 for check digit
    end

    def bank_ref
      Current.acp.bank_reference
    end

    def add_checksum_digit(string)
      "#{string}#{checksum_digit(string)}"
    end

    def checksum_digit(string)
      string = string.gsub(/\D/, "")
      carry = 0
      string.split(//).each { |char| carry = CHECKSUM_SERIES[(carry + char.to_i) % 10] }
      (10 - carry) % 10
    end
  end
end

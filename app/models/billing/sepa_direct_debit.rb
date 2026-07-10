# frozen_string_literal: true

module Billing
  class SEPADirectDebit
    SCHEMA = "pain.008.001.08"
    PAIN_008_001_08 = SCHEMA
    SCHEMAS = [ SCHEMA ].freeze
    AUTOMATIC_ORDER_UPLOAD_DELAY = 3.days

    def initialize(invoices, schema: SCHEMA, message_id: nil, generated_at: nil)
      @invoices = Array(invoices).select { it.sepa? && it.open? }
      @schema = schema
      @message_id = message_id
      @generated_at = generated_at
    end

    def blank?
      @invoices.none?
    end

    def xml
      return if blank?

      case schema
      when PAIN_008_001_08
        Pain008.new(
          @invoices,
          message_id: @message_id,
          generated_at: @generated_at).xml
      else
        raise ArgumentError, "Unsupported SEPA direct debit schema: #{schema.inspect}"
      end
    end

    def filename
      [
        Invoice.model_name.human(count: 2).downcase,
        Date.current.strftime("%Y%m%d"),
        "pain.xml"
      ].join("-")
    end

    private

    attr_reader :schema
  end
end

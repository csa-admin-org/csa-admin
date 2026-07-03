# frozen_string_literal: true

require "sepa_king"

module Billing
  class SEPADirectDebit
    SCHEMA = "pain.008.001.02"
    PAIN_008_001_08 = "pain.008.001.08"
    SCHEMAS = [ SCHEMA, PAIN_008_001_08 ].freeze
    AUTOMATIC_ORDER_UPLOAD_DELAY = 3.days

    def initialize(invoices, schema: SCHEMA)
      @invoices = Array(invoices).select { it.sepa? && it.open? }
      @schema = schema
    end

    def blank?
      @invoices.none?
    end

    def xml
      return if blank?

      case schema
      when SCHEMA
        sdd = base
        sdd = add_transactions(sdd)
        sdd.to_xml(SCHEMA)
      when PAIN_008_001_08
        Pain008.new(@invoices).xml
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

      def base
        SEPA::DirectDebit.new(
          name: Current.org.creditor_name,
          iban: Current.org.iban,
          creditor_identifier: Current.org.sepa_creditor_identifier)
      end

      def add_transactions(sdd)
        @invoices.each do |invoice|
          sdd.add_transaction(
            name: invoice.sepa_debtor_name,
            iban: invoice.sepa_mandate.iban,
            amount: invoice.amount,
            currency: Current.org.currency_code,
            instruction: [ invoice.member_id, invoice.id ].join("-"),
            reference: invoice.reference,
            batch_booking: false, # Disable "Sammelbuchung / Einzelbuchung"
            mandate_id: invoice.sepa_mandate.umr,
            mandate_date_of_signature: invoice.sepa_mandate.signed_on,
            local_instrument: "CORE", # "Basis-Lastschrift"
            sequence_type: "OOFF") # "Einmalige Lastschrift"
        end
        sdd
      end
  end
end

# frozen_string_literal: true

require "sepa_king"

module Billing
  class SEPADirectDebit
    SCHEMA = "pain.008.001.02"
    AUTOMATIC_ORDER_UPLOAD_DELAY = 3.days

    def initialize(invoices)
      @invoices = Array(invoices).select { it.sepa? && it.open? }
    end

    def blank?
      @invoices.none?
    end

    def xml
      return if blank?

      sdd = base
      sdd = add_transactions(sdd)
      sdd.to_xml(SCHEMA)
    end

    def filename
      [
        Invoice.model_name.human(count: 2).downcase,
        Date.current.strftime("%Y%m%d"),
        "pain.xml"
      ].join("-")
    end

    private

    def base
      SEPA::DirectDebit.new(
        name: Current.org.creditor_name,
        iban: Current.org.iban,
        creditor_identifier: Current.org.sepa_creditor_identifier)
    end

    def add_transactions(sdd)
      @invoices.each do |invoice|
        sdd.add_transaction(
          name: invoice.sepa_metadata["name"],
          iban: invoice.sepa_metadata["iban"],
          amount: invoice.amount,
          currency: Current.org.currency_code,
          instruction: [ invoice.member_id, invoice.id ].join("-"),
          reference: invoice.reference,
          batch_booking: false, # Disable "Sammelbuchung / Einzelbuchung"
          mandate_id: invoice.sepa_metadata["mandate_id"],
          mandate_date_of_signature: Date.parse(invoice.sepa_metadata["mandate_signed_on"]),
          local_instrument: "CORE", # "Basis-Lastschrift"
          sequence_type: "OOFF") # "Einmalige Lastschrift"
      end
      sdd
    end
  end
end

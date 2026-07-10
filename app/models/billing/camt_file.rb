# frozen_string_literal: true

require "digest"
require "ostruct"

module Billing
  class CamtFile
    UnsupportedFileError = Class.new(StandardError)
    PaymentData = Class.new(OpenStruct)

    REVERSAL_TEXTS = [ "Retourenbelastung" ]

    def self.process!(file)
      data = new(file).payments_data
      PaymentsProcessor.new(data).process!
    end

    def initialize(*files)
      @files = files.one? && files.first.is_a?(Array) ? files.first : files
    end

    def payments_data
      @files.flat_map do |file|
        xml = file_content(file)
        parse(Parser.new.parse(xml), xml)
      end
    rescue Parser::UnsupportedFileError => e
      report_unexpected_file!(e.original_error)
      raise UnsupportedFileError, e.message
    end

    private

    def report_unexpected_file!(error)
      Billing::EBICS::SafeContext.report_unexpected(error,
        context: Billing::EBICS::SafeContext.payloads_context(@files))
    end

    def parse(result, xml)
      xml_digest = Digest::SHA256.hexdigest(xml)

      case result.origin
      when "camt.054" then parse_camt54(result.document, xml_digest)
      when "camt.053" then parse_camt53(result.document, xml_digest)
      else raise UnsupportedFileError, "Invalid format: #{result.origin}"
      end
    end

    def parse_camt54(camt, xml_digest)
      origin = "camt.054"
      camt.notifications.flat_map(&:entries).each_with_index.flat_map do |entry, entry_index|
        date = entry.value_date
        entry.transactions.each_with_index.filter_map do |transaction, transaction_index|
          ref = creditor_reference(transaction)
          if transaction.credit?
            if Billing.reference.valid?(ref)
              payload = Billing.reference.payload(ref)
              PaymentData.new(
                origin: origin,
                member_id: payload[:member_id],
                invoice_id: payload[:invoice_id],
                amount: transaction.amount,
                date: date,
                fingerprint: payment_fingerprint(
                  origin,
                  entry: entry,
                  transaction: transaction,
                  entry_index: entry_index,
                  transaction_index: transaction_index,
                  xml_digest: xml_digest))
            elsif Billing.reference.unknown?(ref)
              Rails.event.notify(:unknown_payment_reference,
                origin: origin,
                amount: transaction.amount,
                date: date,
                ref: ref)
              nil
            end
          end
        end
      end
    end

    def creditor_reference(transaction)
      return transaction.creditor_reference_information&.creditor_reference if transaction.respond_to?(:creditor_reference_information)

      transaction.creditor_reference
    end

    def parse_camt53(camt, xml_digest)
      origin = "camt.053"
      camt.statements.flat_map(&:entries).each_with_index.flat_map do |entry, entry_index|
        date = entry.value_date

        transactions_data = entry.transactions.each_with_index.filter_map do |transaction, transaction_index|
          ref = transaction.remittance_information
          if transaction.credit?
            if Billing.reference.valid?(ref)
              payload = Billing.reference.payload(ref)
              PaymentData.new(
                origin: origin,
                member_id: payload[:member_id],
                invoice_id: payload[:invoice_id],
                amount: transaction.amount,
                date: date,
                fingerprint: payment_fingerprint(
                  origin,
                  entry: entry,
                  transaction: transaction,
                  entry_index: entry_index,
                  transaction_index: transaction_index,
                  xml_digest: xml_digest))
            elsif Billing.reference.unknown?(ref)
              Rails.event.notify(:unknown_payment_reference,
                origin: origin,
                amount: transaction.amount,
                date: date,
                ref: ref)
              nil
            end
          elsif transaction.debit? && entry.additional_information.in?(REVERSAL_TEXTS)
            if Billing.reference.valid?(ref)
              payload = Billing.reference.payload(ref)
              ref = Billing.reference.extract_ref(ref)
              PaymentData.new(
                origin: origin,
                member_id: payload[:member_id],
                invoice_id: payload[:invoice_id],
                amount: -1 * transaction.amount,
                date: date,
                fingerprint: payment_fingerprint(
                  origin,
                  entry: entry,
                  transaction: transaction,
                  entry_index: entry_index,
                  transaction_index: transaction_index,
                  xml_digest: xml_digest))
            elsif Billing.reference.unknown?(ref)
              Rails.event.notify(:unknown_reversal_payment_reference,
                origin: origin,
                amount: transaction.amount,
                date: date,
                ref: ref)
              nil
            end
          end
        end

        if transactions_data.empty? && entry.credit?
          transactions_data = parse_camt53_entry_without_transactions(entry, origin, date, entry_index, xml_digest)
        end

        transactions_data
      end
    end

    def parse_camt53_entry_without_transactions(entry, origin, date, entry_index, xml_digest)
      ref = Billing.reference.extract_ref(entry.additional_information)
      if Billing.reference.valid?(ref)
        payload = Billing.reference.payload(ref)
        [ PaymentData.new(
          origin: origin,
          member_id: payload[:member_id],
          invoice_id: payload[:invoice_id],
          amount: entry.amount,
          date: date,
          fingerprint: payment_fingerprint(
            origin,
            entry: entry,
            entry_index: entry_index,
            xml_digest: xml_digest)) ]
      elsif Billing.reference.unknown?(ref)
        Rails.event.notify(:unknown_payment_reference,
          origin: origin,
          amount: entry.amount,
          date: date,
          ref: ref)
        []
      else
        []
      end
    end

    def file_content(file)
      return file if file.is_a?(String)

      file.rewind if file.respond_to?(:rewind)
      file.read
    ensure
      file.rewind if file.respond_to?(:rewind)
    end

    def payment_fingerprint(_origin, entry:, transaction: nil, entry_index:, transaction_index: nil, xml_digest:)
      if bank_reference = transaction&.bank_reference.presence
        fingerprint("camt", "transaction_bank_reference", bank_reference)
      elsif transaction_id = transaction&.transaction_id.presence
        fingerprint("camt", "transaction_id", transaction_id)
      elsif bank_reference = entry.bank_reference.presence
        fingerprint(
          "camt",
          "entry_bank_reference",
          bank_reference,
          entry.transactions.many? ? transaction_index : nil)
      else
        fingerprint("camt", "xml", xml_digest, entry_index, transaction_index)
      end
    end

    def fingerprint(*parts)
      Digest::SHA256.hexdigest(parts.compact.join("\0"))
    end
  end
end

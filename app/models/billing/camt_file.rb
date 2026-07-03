# frozen_string_literal: true

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
      @files = Array(*files)
    end

    def payments_data
      @files.flat_map { |file| parse(Parser.new.parse(file)) }
    rescue Parser::UnsupportedFileError => e
      report_unexpected_file!(e.original_error)
      raise UnsupportedFileError, e.message
    end

    private

    def report_unexpected_file!(error)
      Billing::EBICS::SafeContext.report_unexpected(error,
        context: Billing::EBICS::SafeContext.payloads_context(@files))
    end

    def parse(result)
      case result.origin
      when "camt.054" then parse_camt54(result.document)
      when "camt.053" then parse_camt53(result.document)
      else raise UnsupportedFileError, "Invalid format: #{result.origin}"
      end
    end

    def parse_camt54(camt)
      origin = "camt.054"
      camt.notifications.flat_map { |notification|
        notification.entries.flat_map { |entry|
          date = entry.value_date
          entry.transactions.map { |transaction|
            ref = creditor_reference(transaction)
            if transaction.credit?
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date)
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_payment_reference,
                  origin: origin,
                  amount: transaction.amount,
                  date: date,
                  ref: ref)
                nil
              end
            end
          }.compact
        }
      }
    end

    def creditor_reference(transaction)
      return transaction.creditor_reference_information&.creditor_reference if transaction.respond_to?(:creditor_reference_information)

      transaction.creditor_reference
    end

    def parse_camt53(camt)
      origin = "camt.053"
      camt.statements.flat_map { |statement|
        statement.entries.flat_map { |entry|
          date = entry.value_date

          transactions_data = entry.transactions.map { |transaction|
            ref = transaction.remittance_information
            if transaction.credit?
              if Billing.reference.valid?(ref)
                payload = Billing.reference.payload(ref)
                PaymentData.new(
                  origin: origin,
                  member_id: payload[:member_id],
                  invoice_id: payload[:invoice_id],
                  amount: transaction.amount,
                  date: date)
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
                  date: date)
              elsif Billing.reference.unknown?(ref)
                Rails.event.notify(:unknown_reversal_payment_reference,
                  origin: origin,
                  amount: transaction.amount,
                  date: date,
                  ref: ref)
                nil
              end
            end
          }.compact

          if transactions_data.empty? && entry.credit?
            transactions_data = parse_camt53_entry_without_transactions(entry, origin, date)
          end

          transactions_data
        }
      }
    end

    def parse_camt53_entry_without_transactions(entry, origin, date)
      ref = Billing.reference.extract_ref(entry.additional_information)
      if Billing.reference.valid?(ref)
        payload = Billing.reference.payload(ref)
        [ PaymentData.new(
          origin: origin,
          member_id: payload[:member_id],
          invoice_id: payload[:invoice_id],
          amount: entry.amount,
          date: date) ]
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
  end
end
